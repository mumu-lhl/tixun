part of "expression.dart";

int? _binaryPrecedence(String op) => switch (op) {
  "||" => 1,
  "&&" => 2,
  "==" || "!=" => 3,
  "<" || "<=" || ">" || ">=" => 4,
  "+" || "-" => 5,
  "*" || "/" => 6,
  "^" => 8,
  _ => null,
};

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  var _pos = 0;

  /// Current parenthesis nesting depth. Parentheses do not create AST
  /// nodes, so without this guard a pathological run of `((((...` could
  /// overflow the parser stack before the AST depth check runs.
  var _parenDepth = 0;

  /// Current recursive-descent depth (entries into `_parseExpr` /
  /// `_parsePrefix`). Guards the descent itself: the AST depth check
  /// only runs after a subtree is built, so a long unary-minus or
  /// right-associative `^` chain would otherwise overflow the stack
  /// before any check runs.
  var _recursionDepth = 0;

  void _enterRecursion() {
    _recursionDepth++;
    if (_recursionDepth > expressionMaxRecursionDepth) {
      throw FormatException(
        "Expression is too deeply nested (parser recursion depth "
        "$_recursionDepth > $expressionMaxRecursionDepth).",
      );
    }
  }

  void _exitRecursion() {
    _recursionDepth--;
  }

  _Token get _peek => _tokens[_pos];
  _Token _advance() => _tokens[_pos++];

  void _enterParen(int offset) {
    _parenDepth++;
    // The parenthesis cap follows the parser recursion budget, not the
    // AST depth limit: `(` * 33 around a literal is only one AST level
    // deep, so capping it at 32 would reject a shallow expression.
    // Each paren level costs two recursion frames (`_parseExpr` +
    // `_parsePrefix`), and the innermost literal costs two more, so
    // (128 - 2) / 2 = 63 parens fit under the 128-frame budget.
    const parenCap = (expressionMaxRecursionDepth - 2) ~/ 2;
    if (_parenDepth > parenCap) {
      throw FormatException(
        "Expression is too deeply nested (more than $parenCap levels of "
        "parentheses).",
      );
    }
  }

  _Expr parse() {
    if (_peek.kind == _TokenKind.eof) {
      throw const FormatException("Empty expression.");
    }
    final expr = _parseExpr(0);
    if (_peek.kind != _TokenKind.eof) {
      throw FormatException(
        'Unexpected "${_peek.text}" at offset ${_peek.offset}.',
      );
    }
    _checkDepth(expr);
    return expr;
  }

  void _checkDepth(_Expr expr) {
    if (expr.depth > expressionMaxDepth) {
      throw FormatException(
        "Expression is too deeply nested (depth ${expr.depth} > "
        "$expressionMaxDepth).",
      );
    }
  }

  _Expr _parseExpr(int minPrecedence) {
    _enterRecursion();
    try {
      var left = _parsePrefix();
      while (true) {
        final tok = _peek;
        if (tok.kind != _TokenKind.op) break;
        final prec = _binaryPrecedence(tok.text);
        if (prec == null || prec < minPrecedence) break;
        _advance();
        // `^` is right-associative; all other binary operators are left-assoc.
        final nextMin = tok.text == "^" ? prec : prec + 1;
        final right = _parseExpr(nextMin);
        left = _Binary(tok.text, left, right, offset: tok.offset);
        _checkDepth(left);
      }
      return left;
    } finally {
      _exitRecursion();
    }
  }

  _Expr _parsePrefix() {
    _enterRecursion();
    try {
      return _parsePrefixBody();
    } finally {
      _exitRecursion();
    }
  }

  _Expr _parsePrefixBody() {
    final tok = _advance();
    switch (tok.kind) {
      case _TokenKind.number:
        return _Literal(tok.numberValue!, offset: tok.offset);
      case _TokenKind.ident:
        if (_peek.kind == _TokenKind.lparen) {
          _enterParen(tok.offset);
          final call = _parseCall(tok.text, tok.offset);
          _parenDepth--;
          return call;
        }
        if (tok.text == "if" || _functions.contains(tok.text)) {
          // A function name on its own is not a variable: `sin` with no
          // call cannot be evaluated, and silently reading it as a
          // variable would hide a typo.
          throw FormatException(
            'Function "${tok.text}" needs arguments: use '
            '"${tok.text}(...)" at offset ${tok.offset}.',
          );
        }
        return _Variable(tok.text, offset: tok.offset);
      case _TokenKind.lparen:
        _enterParen(tok.offset);
        final inner = _parseExpr(0);
        if (_peek.kind != _TokenKind.rparen) {
          throw FormatException('Expected ")" at offset ${_peek.offset}.');
        }
        _advance();
        _parenDepth--;
        return inner;
      case _TokenKind.op:
        if (tok.text == "-" || tok.text == "+" || tok.text == "!") {
          // Unary minus / plus / logical not bind tighter than + - * /
          // but looser than ^, so -x^2 parses as -(x^2).
          final operand = _parseExpr(7);
          final expr = _Unary(tok.text, operand, offset: tok.offset);
          _checkDepth(expr);
          return expr;
        }
        throw FormatException(
          'Unexpected operator "${tok.text}" at offset ${tok.offset}.',
        );
      case _TokenKind.rparen:
      case _TokenKind.comma:
        throw FormatException(
          'Unexpected "${tok.text}" at offset ${tok.offset}.',
        );
      case _TokenKind.eof:
        throw FormatException("Expected an operand at offset ${tok.offset}.");
    }
  }

  _Expr _parseCall(String name, int offset) {
    _advance(); // consume '('
    if (name == "if") {
      final cond = _parseExpr(0);
      _expectComma();
      final thenBranch = _parseExpr(0);
      _expectComma();
      final elseBranch = _parseExpr(0);
      if (_peek.kind == _TokenKind.comma) {
        throw FormatException(
          'Function "if" takes exactly 3 arguments, but more were given '
          "at offset ${_peek.offset}.",
        );
      }
      _expectRparen();
      final expr = _If(cond, thenBranch, elseBranch, offset: offset);
      _checkDepth(expr);
      return expr;
    }
    if (!_functions.contains(name)) {
      throw FormatException('Unknown function "$name" at offset $offset.');
    }
    final arg = _parseExpr(0);
    _expectSingleArg(name, offset);
    final expr = _Call(name, arg, offset: offset);
    _checkDepth(expr);
    return expr;
  }

  /// After a single-argument function's first argument, a comma means
  /// the caller passed too many arguments; report that instead of the
  /// confusing `Expected ")"` from [_expectRparen].
  void _expectSingleArg(String name, int offset) {
    if (_peek.kind == _TokenKind.comma) {
      throw FormatException(
        'Function "$name" takes exactly 1 argument, but more were given '
        "at offset ${_peek.offset}.",
      );
    }
    _expectRparen();
  }

  void _expectComma() {
    if (_peek.kind != _TokenKind.comma) {
      throw FormatException('Expected "," at offset ${_peek.offset}.');
    }
    _advance();
  }

  void _expectRparen() {
    if (_peek.kind != _TokenKind.rparen) {
      throw FormatException('Expected ")" at offset ${_peek.offset}.');
    }
    _advance();
  }
}

enum _TokenKind { number, ident, op, lparen, rparen, comma, eof }

class _Token {
  const _Token(this.kind, this.text, this.offset, [this.numberValue]);

  final _TokenKind kind;
  final String text;
  final int offset;
  final double? numberValue;
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  bool isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
  bool isIdentStart(String c) =>
      (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7a) ||
      (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5a) ||
      c == "_";
  bool isIdentPart(String c) => isIdentStart(c) || isDigit(c);

  while (i < source.length) {
    final c = source[i];
    if (c == " " || c == "\t" || c == "\n" || c == "\r") {
      i++;
      continue;
    }
    if (isDigit(c) ||
        (c == "." && i + 1 < source.length && isDigit(source[i + 1]))) {
      final start = i;
      while (i < source.length && isDigit(source[i])) {
        i++;
      }
      if (i < source.length && source[i] == ".") {
        i++;
        while (i < source.length && isDigit(source[i])) {
          i++;
        }
      }
      if (i < source.length && (source[i] == "e" || source[i] == "E")) {
        var j = i + 1;
        if (j < source.length && (source[j] == "+" || source[j] == "-")) {
          j++;
        }
        if (j >= source.length || !isDigit(source[j])) {
          // `1e` / `1e+` / `1e+x`: the exponent has no digits, so this
          // is a malformed number, not the number 1 followed by the
          // identifier `e`.
          throw FormatException(
            'Invalid number "${source.substring(start, j)}" at offset $start.',
          );
        }
        i = j;
        while (i < source.length && isDigit(source[i])) {
          i++;
        }
      }
      final text = source.substring(start, i);
      final value = double.tryParse(text);
      if (value == null || !value.isFinite) {
        throw FormatException('Invalid number "$text" at offset $start.');
      }
      tokens.add(_Token(_TokenKind.number, text, start, value));
      continue;
    }
    if (isIdentStart(c)) {
      final start = i;
      while (i < source.length && isIdentPart(source[i])) {
        i++;
      }
      tokens.add(_Token(_TokenKind.ident, source.substring(start, i), start));
      continue;
    }
    final two = i + 1 < source.length ? source.substring(i, i + 2) : "";
    if (two == "<=" ||
        two == ">=" ||
        two == "==" ||
        two == "!=" ||
        two == "&&" ||
        two == "||") {
      tokens.add(_Token(_TokenKind.op, two, i));
      i += 2;
      continue;
    }
    if (c == "+" ||
        c == "-" ||
        c == "*" ||
        c == "/" ||
        c == "^" ||
        c == "<" ||
        c == ">" ||
        c == "!") {
      tokens.add(_Token(_TokenKind.op, c, i));
      i++;
      continue;
    }
    if (c == "(") {
      tokens.add(_Token(_TokenKind.lparen, c, i));
      i++;
      continue;
    }
    if (c == ")") {
      tokens.add(_Token(_TokenKind.rparen, c, i));
      i++;
      continue;
    }
    if (c == ",") {
      tokens.add(_Token(_TokenKind.comma, c, i));
      i++;
      continue;
    }
    throw FormatException('Unexpected character "$c" at offset $i.');
  }
  tokens.add(_Token(_TokenKind.eof, "", source.length));
  return tokens;
}
