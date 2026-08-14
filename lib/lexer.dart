import 'token.dart';

final class LexError implements Exception {
  final String message;
  final SourcePos pos;

  /// Source file when known (e.g. during multi-file project load).
  final String? path;

  const LexError(this.message, this.pos, {this.path});

  @override
  String toString() {
    final p = path;
    if (p == null || p.isEmpty) return '${pos.line}:${pos.col}: $message';
    return '$p:${pos.line}:${pos.col}: $message';
  }
}

final class Lexer {
  final String source;
  int _i = 0;
  int _line = 1;
  int _col = 1;

  /// `//` comments in source order. Not in the token stream.
  final List<SourceComment> comments = [];

  Lexer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (true) {
      final t = _next();
      tokens.add(t);
      if (t.kind == TokenKind.eof) break;
    }
    return tokens;
  }

  Token _next() {
    _skipWhitespace();
    if (_atEnd) {
      return Token(TokenKind.eof, '', SourcePos(_line, _col));
    }

    final start = SourcePos(_line, _col);
    final c = _peek;

    if (_isIdentStart(c)) return _identOrKeyword(start);
    if (_isDigit(c)) return _number(start);
    if (c == '"') return _string(start);
    if (c == "'") return _char(start);

    switch (c) {
      case '(':
        _advance();
        return Token(TokenKind.lParen, '(', start);
      case ')':
        _advance();
        return Token(TokenKind.rParen, ')', start);
      case '{':
        _advance();
        return Token(TokenKind.lBrace, '{', start);
      case '}':
        _advance();
        return Token(TokenKind.rBrace, '}', start);
      case '[':
        _advance();
        return Token(TokenKind.lBracket, '[', start);
      case ']':
        _advance();
        return Token(TokenKind.rBracket, ']', start);
      case '+':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.plusEqual, '+=', start);
        }
        return Token(TokenKind.plus, '+', start);
      case '-':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.minusEqual, '-=', start);
        }
        return Token(TokenKind.minus, '-', start);
      case '*':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.starEqual, '*=', start);
        }
        return Token(TokenKind.star, '*', start);
      case '/':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.slashEqual, '/=', start);
        }
        return Token(TokenKind.slash, '/', start);
      case '%':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.percentEqual, '%=', start);
        }
        return Token(TokenKind.percent, '%', start);
      case '&':
        _advance();
        if (!_atEnd && _peek == '&') {
          _advance();
          return Token(TokenKind.ampAmp, '&&', start);
        }
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.ampEqual, '&=', start);
        }
        return Token(TokenKind.ampersand, '&', start);
      case '|':
        _advance();
        if (!_atEnd && _peek == '|') {
          _advance();
          return Token(TokenKind.pipePipe, '||', start);
        }
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.pipeEqual, '|=', start);
        }
        return Token(TokenKind.pipe, '|', start);
      case '^':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.caretEqual, '^=', start);
        }
        return Token(TokenKind.caret, '^', start);
      case '~':
        _advance();
        return Token(TokenKind.tilde, '~', start);
      case '@':
        _advance();
        return Token(TokenKind.atSign, '@', start);
      case ':':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.colonEqual, ':=', start);
        }
        return Token(TokenKind.colon, ':', start);
      case ';':
        _advance();
        return Token(TokenKind.semicolon, ';', start);
      case ',':
        _advance();
        return Token(TokenKind.comma, ',', start);
      case '=':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.equalEqual, '==', start);
        }
        return Token(TokenKind.equal, '=', start);
      case '!':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.bangEqual, '!=', start);
        }
        return Token(TokenKind.bang, '!', start);
      case '<':
        _advance();
        if (!_atEnd && _peek == '<') {
          _advance();
          if (!_atEnd && _peek == '=') {
            _advance();
            return Token(TokenKind.lessLessEqual, '<<=', start);
          }
          return Token(TokenKind.lessLess, '<<', start);
        }
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.lessEqual, '<=', start);
        }
        return Token(TokenKind.less, '<', start);
      case '>':
        _advance();
        if (!_atEnd && _peek == '>') {
          _advance();
          if (!_atEnd && _peek == '=') {
            _advance();
            return Token(TokenKind.greaterGreaterEqual, '>>=', start);
          }
          return Token(TokenKind.greaterGreater, '>>', start);
        }
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.greaterEqual, '>=', start);
        }
        return Token(TokenKind.greater, '>', start);
      case '.':
        // ..< / ..=
        if (_i + 2 < source.length && source[_i + 1] == '.') {
          if (source[_i + 2] == '<') {
            _advance();
            _advance();
            _advance();
            return Token(TokenKind.dotDotLess, '..<', start);
          }
          if (source[_i + 2] == '=') {
            _advance();
            _advance();
            _advance();
            return Token(TokenKind.dotDotEqual, '..=', start);
          }
        }
        _advance();
        return Token(TokenKind.dot, '.', start);
      default:
        throw LexError('unexpected character `$c`', start);
    }
  }

  Token _identOrKeyword(SourcePos start) {
    final buf = StringBuffer();
    while (!_atEnd && _isIdentContinue(_peek)) {
      buf.write(_advance());
    }
    final lexeme = buf.toString();
    return switch (lexeme) {
      'fn' => Token(TokenKind.fn, lexeme, start),
      'struct' => Token(TokenKind.struct, lexeme, start),
      'enum' => Token(TokenKind.enum_, lexeme, start),
      'pub' => Token(TokenKind.pub, lexeme, start),
      'module' => Token(TokenKind.module, lexeme, start),
      'import' => Token(TokenKind.import, lexeme, start),
      'let' => Token(TokenKind.let, lexeme, start),
      'mut' => Token(TokenKind.mut, lexeme, start),
      'cast' => Token(TokenKind.cast, lexeme, start),
      'volatile' => Token(TokenKind.volatile, lexeme, start),
      'true' => Token(TokenKind.true_, lexeme, start),
      'false' => Token(TokenKind.false_, lexeme, start),
      'if' => Token(TokenKind.if_, lexeme, start),
      'else' => Token(TokenKind.else_, lexeme, start),
      'while' => Token(TokenKind.while_, lexeme, start),
      'for' => Token(TokenKind.for_, lexeme, start),
      'in' => Token(TokenKind.in_, lexeme, start),
      'return' => Token(TokenKind.return_, lexeme, start),
      'break' => Token(TokenKind.break_, lexeme, start),
      'continue' => Token(TokenKind.continue_, lexeme, start),
      'defer' => Token(TokenKind.defer_, lexeme, start),
      'or' => Token(TokenKind.or_, lexeme, start),
      'error' => Token(TokenKind.error_, lexeme, start),
      'asm' => Token(TokenKind.asm_, lexeme, start),
      'match' => Token(TokenKind.match_, lexeme, start),
      'when' => Token(TokenKind.when_, lexeme, start),
      'pick' => Token(TokenKind.pick_, lexeme, start),
      'async' => Token(TokenKind.async_, lexeme, start),
      'await' => Token(TokenKind.await_, lexeme, start),
      _ => Token(TokenKind.ident, lexeme, start),
    };
  }

  Token _number(SourcePos start) {
    final buf = StringBuffer();
    if (_peek == '0' &&
        _i + 1 < source.length &&
        (source[_i + 1] == 'x' || source[_i + 1] == 'X')) {
      buf.write(_advance());
      buf.write(_advance());
      if (_atEnd || !_isHexDigit(_peek)) {
        throw LexError('expected hexadecimal digit after `0x`', start);
      }
      while (!_atEnd && (_isHexDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
      return Token(TokenKind.intLit, buf.toString(), start);
    }
    if (_peek == '0' &&
        _i + 1 < source.length &&
        (source[_i + 1] == 'b' || source[_i + 1] == 'B')) {
      buf.write(_advance());
      buf.write(_advance());
      if (_atEnd || !_isBinaryDigit(_peek)) {
        throw LexError('expected binary digit after `0b`', start);
      }
      while (!_atEnd && (_isBinaryDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
      return Token(TokenKind.intLit, buf.toString(), start);
    }
    if (_peek == '0' &&
        _i + 1 < source.length &&
        (source[_i + 1] == 'o' || source[_i + 1] == 'O')) {
      buf.write(_advance());
      buf.write(_advance());
      if (_atEnd || !_isOctalDigit(_peek)) {
        throw LexError('expected octal digit after `0o`', start);
      }
      while (!_atEnd && (_isOctalDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
      return Token(TokenKind.intLit, buf.toString(), start);
    }
    while (!_atEnd && (_isDigit(_peek) || _peek == '_')) {
      buf.write(_advance());
    }
    var isFloat = false;
    if (!_atEnd &&
        _peek == '.' &&
        _i + 1 < source.length &&
        _isDigit(source[_i + 1])) {
      isFloat = true;
      buf.write(_advance()); // .
      while (!_atEnd && (_isDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
    }
    // Exponent: `e`/`E` with an optional sign, e.g. `1e9`, `1.5e-3`. Only consume
    // when a digit follows, so `1end` stays `1` + ident `end`.
    if (!_atEnd && (_peek == 'e' || _peek == 'E') && _hasExponentDigits()) {
      isFloat = true;
      buf.write(_advance()); // e/E
      if (!_atEnd && (_peek == '+' || _peek == '-')) {
        buf.write(_advance());
      }
      while (!_atEnd && (_isDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
    }
    return Token(
        isFloat ? TokenKind.floatLit : TokenKind.intLit, buf.toString(), start);
  }

  Token _string(SourcePos start) {
    _advance(); // opening "
    final buf = StringBuffer();
    while (!_atEnd && _peek != '"') {
      if (_peek == '\n') {
        throw LexError('unterminated string', start);
      }
      if (_peek == '\\') {
        _advance();
        if (_atEnd) throw LexError('unterminated string', start);
        final esc = _advance();
        switch (esc) {
          case 'n':
            buf.write('\n');
          case 't':
            buf.write('\t');
          case '\\':
            buf.write('\\');
          case '"':
            buf.write('"');
          case '\$':
            // Literal `$` in an interpolated string (see [kInterpEscapedDollar]).
            buf.write('\u{E000}');
          default:
            throw LexError('unknown escape sequence `\\$esc`', start);
        }
      } else {
        buf.write(_advance());
      }
    }
    if (_atEnd) throw LexError('unterminated string', start);
    _advance(); // closing "
    return Token(TokenKind.string, buf.toString(), start);
  }

  /// Character literal → [TokenKind.intLit] with source spelling (`'A'`, `'\n'`).
  /// Typed as untyped int in the checker; emitted as a C `'…'` literal.
  Token _char(SourcePos start) {
    final buf = StringBuffer();
    buf.write(_advance()); // opening '
    if (_atEnd) throw LexError('unterminated character literal', start);
    if (_peek == "'") {
      throw LexError('empty character literal', start);
    }
    if (_peek == '\n') {
      throw LexError('unterminated character literal', start);
    }
    if (_peek == '\\') {
      buf.write(_advance());
      if (_atEnd) throw LexError('unterminated character literal', start);
      final esc = _advance();
      switch (esc) {
        case 'n':
        case 't':
        case '0':
        case '\\':
        case "'":
          buf.write(esc);
        default:
          throw LexError('unknown escape sequence `\\$esc`', start);
      }
    } else {
      final ch = _advance();
      // Single ASCII code unit (printable or space); no multi-char literals.
      final code = ch.codeUnitAt(0);
      if (code > 0x7F) {
        throw LexError('character literal must be ASCII', start);
      }
      buf.write(ch);
    }
    if (_atEnd || _peek != "'") {
      throw LexError('expected closing `\'` in character literal', start);
    }
    buf.write(_advance());
    return Token(TokenKind.intLit, buf.toString(), start);
  }

  void _skipWhitespace() {
    while (!_atEnd) {
      final c = _peek;
      if (c == ' ' || c == '\t' || c == '\r') {
        _advance();
      } else if (c == '\n') {
        _advance();
      } else if (c == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        _collectComment();
      } else {
        break;
      }
    }
  }

  void _collectComment() {
    final pos = SourcePos(_line, _col);
    final trailing = _commentIsTrailing();
    final start = _i;
    while (!_atEnd && _peek != '\n') {
      _advance();
    }
    var text = source.substring(start, _i);
    if (text.endsWith('\r')) {
      text = text.substring(0, text.length - 1);
    }
    comments.add(SourceComment(text, pos, trailing: trailing));
  }

  /// True when this `//` has non-whitespace code to its left on the same line.
  bool _commentIsTrailing() {
    var j = _i - 1;
    while (j >= 0) {
      final c = source[j];
      if (c == '\n') return false;
      if (c != ' ' && c != '\t' && c != '\r') return true;
      j--;
    }
    return false;
  }

  bool get _atEnd => _i >= source.length;

  String get _peek => source[_i];

  String _advance() {
    final c = source[_i++];
    if (c == '\n') {
      _line++;
      _col = 1;
    } else {
      _col++;
    }
    return c;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || // A-Z
        (u >= 97 && u <= 122) || // a-z
        u == 95; // _
  }

  static bool _isIdentContinue(String c) {
    return _isIdentStart(c) || _isDigit(c);
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }

  static bool _isBinaryDigit(String c) => c == '0' || c == '1';

  static bool _isOctalDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 55; // 0-7
  }

  /// True when the `e`/`E` at the cursor is a float exponent: optional sign then
  /// at least one digit.
  bool _hasExponentDigits() {
    var j = _i + 1;
    if (j < source.length && (source[j] == '+' || source[j] == '-')) j++;
    return j < source.length && _isDigit(source[j]);
  }

  static bool _isHexDigit(String c) {
    final u = c.codeUnitAt(0);
    return _isDigit(c) || (u >= 65 && u <= 70) || (u >= 97 && u <= 102);
  }
}
