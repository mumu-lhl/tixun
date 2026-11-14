/// Restricted expression language for TiXun Visual DSL v1.
///
/// A parsed expression is a small AST over doubles. The language supports
/// literals, variables (`x`, `t`, parameter names), `+ - * / ^` (`^` is
/// right-associative), unary minus, parentheses, the functions
/// `sin cos tan asin acos atan sinh cosh tanh exp ln log sqrt abs floor ceil
/// sign`, `if(cond, a, b)` with `< <= > >= == != && || !`, and the constants
/// `pi` and `e`.
///
/// `log` is base-10 (`ln` is the natural log). Comparisons and logic return
/// `1.0` for true and `0.0` for false. `&&`, `||` and `if` are lazy: the
/// untaken branch is never evaluated, so `x != 0 && 1 / x > 2` is safe.
///
/// Nothing here executes generated code: parsing builds an AST and
/// [evaluate] walks it. AST depth is limited to 32 (see [maxDepth]); a
/// deeper expression throws [FormatException] at parse time, which also
/// bounds evaluation recursion.
library;

import 'dart:math' as math;

/// Maximum AST depth (root = 1). A flat `a + b + c + ...` chain builds a
/// left-deep tree, so very long flat sums count against this limit too;
/// model-generated expressions are short, and the validator reports the
/// failure so the model can retry with a shorter form.
const expressionMaxDepth = 32;

/// A parsed expression. Obtain via [Expression.parse]; evaluate with
/// [evaluate].
class Expression {
  const Expression._(this._root);

  final _Expr _root;

  /// Parses [source] into an expression.
  ///
  /// Throws [FormatException] with a readable message on syntax errors,
  /// unknown functions, wrong argument counts, or AST depth over
  /// [expressionMaxDepth].
  static Expression parse(String source) {
    final tokens = _tokenize(source);
    final parser = _Parser(tokens);
    final root = parser.parse();
    return Expression._(root);
  }

  /// Evaluates the expression with the given variable values.
  ///
  /// Throws [FormatException] on an unknown variable or a non-finite
  /// (infinite/NaN) intermediate or final result. Variables named `pi` and
  /// `e` resolve to their constants unless shadowed by [vars].
  double evaluate(Map<String, double> vars) => _root.eval(vars);

  /// Variable names referenced by this expression (function names excluded).
  /// Includes `pi`/`e` when referenced; the validator treats those as
  /// always allowed.
  Set<String> get variables => _root.variables;

  @override
  String toString() => _root.toString();
}

// ---------------------------------------------------------------------------
// Tokenizer
// ---------------------------------------------------------------------------

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
      c == '_';
  bool isIdentPart(String c) => isIdentStart(c) || isDigit(c);

  while (i < source.length) {
    final c = source[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      i++;
      continue;
    }
    if (isDigit(c) ||
        (c == '.' && i + 1 < source.length && isDigit(source[i + 1]))) {
      final start = i;
      while (i < source.length && isDigit(source[i])) {
        i++;
      }
      if (i < source.length && source[i] == '.') {
        i++;
        while (i < source.length && isDigit(source[i])) {
          i++;
        }
      }
      if (i < source.length && (source[i] == 'e' || source[i] == 'E')) {
        var j = i + 1;
        if (j < source.length && (source[j] == '+' || source[j] == '-')) {
          j++;
        }
        if (j < source.length && isDigit(source[j])) {
          i = j;
          while (i < source.length && isDigit(source[i])) {
            i++;
          }
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
    final two = i + 1 < source.length ? source.substring(i, i + 2) : '';
    if (two == '<=' ||
        two == '>=' ||
        two == '==' ||
        two == '!=' ||
        two == '&&' ||
        two == '||') {
      tokens.add(_Token(_TokenKind.op, two, i));
      i += 2;
      continue;
    }
    if (c == '+' ||
        c == '-' ||
        c == '*' ||
        c == '/' ||
        c == '^' ||
        c == '<' ||
        c == '>' ||
        c == '!') {
      tokens.add(_Token(_TokenKind.op, c, i));
      i++;
      continue;
    }
    if (c == '(') {
      tokens.add(_Token(_TokenKind.lparen, c, i));
      i++;
      continue;
    }
    if (c == ')') {
      tokens.add(_Token(_TokenKind.rparen, c, i));
      i++;
      continue;
    }
    if (c == ',') {
      tokens.add(_Token(_TokenKind.comma, c, i));
      i++;
      continue;
    }
    throw FormatException('Unexpected character "$c" at offset $i.');
  }
  tokens.add(_Token(_TokenKind.eof, '', source.length));
  return tokens;
}

// ---------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------

sealed class _Expr {
  const _Expr();

  double eval(Map<String, double> vars);
  Set<String> get variables;
  int get depth;
}

class _Literal extends _Expr {
  const _Literal(this.value);

  final double value;

  @override
  double eval(Map<String, double> vars) => value;

  @override
  Set<String> get variables => const {};

  @override
  int get depth => 1;

  @override
  String toString() => value.toString();
}

class _Variable extends _Expr {
  const _Variable(this.name);

  final String name;

  @override
  double eval(Map<String, double> vars) {
    final v = vars[name];
    if (v != null) return _finite(v, name);
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;
    throw FormatException('Unknown variable "$name".');
  }

  @override
  Set<String> get variables => {name};

  @override
  int get depth => 1;

  @override
  String toString() => name;
}

class _Unary extends _Expr {
  const _Unary(this.op, this.operand);

  final String op;
  final _Expr operand;

  @override
  double eval(Map<String, double> vars) {
    final v = operand.eval(vars);
    final result = op == '-' ? -v : (v == 0 ? 1.0 : 0.0);
    return _finite(result, op);
  }

  @override
  Set<String> get variables => operand.variables;

  @override
  int get depth => 1 + operand.depth;

  @override
  String toString() => '($op$operand)';
}

class _Binary extends _Expr {
  const _Binary(this.op, this.left, this.right);

  final String op;
  final _Expr left;
  final _Expr right;

  @override
  double eval(Map<String, double> vars) {
    // Short-circuit logic: the untaken branch is never evaluated.
    if (op == '&&') {
      if (left.eval(vars) == 0) return 0;
      return right.eval(vars) == 0 ? 0 : 1;
    }
    if (op == '||') {
      if (left.eval(vars) != 0) return 1;
      return right.eval(vars) == 0 ? 0 : 1;
    }
    final l = left.eval(vars);
    final r = right.eval(vars);
    final result = switch (op) {
      '+' => l + r,
      '-' => l - r,
      '*' => l * r,
      '/' => l / r,
      '^' => math.pow(l, r).toDouble(),
      '<' => l < r ? 1.0 : 0.0,
      '<=' => l <= r ? 1.0 : 0.0,
      '>' => l > r ? 1.0 : 0.0,
      '>=' => l >= r ? 1.0 : 0.0,
      '==' => l == r ? 1.0 : 0.0,
      '!=' => l != r ? 1.0 : 0.0,
      _ => throw FormatException('Unknown operator "$op".'),
    };
    return _finite(result, op);
  }

  @override
  Set<String> get variables => {...left.variables, ...right.variables};

  @override
  int get depth => 1 + math.max(left.depth, right.depth);

  @override
  String toString() => '($left $op $right)';
}

class _Call extends _Expr {
  const _Call(this.name, this.arg);

  final String name;
  final _Expr arg;

  @override
  double eval(Map<String, double> vars) {
    final v = arg.eval(vars);
    final result = switch (name) {
      'sin' => math.sin(v),
      'cos' => math.cos(v),
      'tan' => math.tan(v),
      'asin' => math.asin(v),
      'acos' => math.acos(v),
      'atan' => math.atan(v),
      'sinh' => _sinh(v),
      'cosh' => _cosh(v),
      'tanh' => _tanh(v),
      'exp' => math.exp(v),
      'ln' => math.log(v),
      'log' => math.log(v) / math.ln10,
      'sqrt' => math.sqrt(v),
      'abs' => v.abs(),
      'floor' => v.floorToDouble(),
      'ceil' => v.ceilToDouble(),
      'sign' => v == 0 ? 0.0 : (v > 0 ? 1.0 : -1.0),
      _ => throw FormatException('Unknown function "$name".'),
    };
    return _finite(result, name);
  }

  @override
  Set<String> get variables => arg.variables;

  @override
  int get depth => 1 + arg.depth;

  @override
  String toString() => '$name($arg)';
}

class _If extends _Expr {
  const _If(this.cond, this.thenBranch, this.elseBranch);

  final _Expr cond;
  final _Expr thenBranch;
  final _Expr elseBranch;

  @override
  double eval(Map<String, double> vars) =>
      cond.eval(vars) != 0 ? thenBranch.eval(vars) : elseBranch.eval(vars);

  @override
  Set<String> get variables => {
    ...cond.variables,
    ...thenBranch.variables,
    ...elseBranch.variables,
  };

  @override
  int get depth =>
      1 + math.max(cond.depth, math.max(thenBranch.depth, elseBranch.depth));

  @override
  String toString() => 'if($cond, $thenBranch, $elseBranch)';
}

double _finite(double value, String where) {
  if (!value.isFinite) {
    throw FormatException('Non-finite result while evaluating "$where".');
  }
  return value;
}

double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;
double _cosh(double v) => (math.exp(v) + math.exp(-v)) / 2;
double _tanh(double v) {
  final e2 = math.exp(2 * v);
  return (e2 - 1) / (e2 + 1);
}

// ---------------------------------------------------------------------------
// Pratt parser
// ---------------------------------------------------------------------------

const _functions = {
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'sinh',
  'cosh',
  'tanh',
  'exp',
  'ln',
  'log',
  'sqrt',
  'abs',
  'floor',
  'ceil',
  'sign',
};

int? _binaryPrecedence(String op) => switch (op) {
  '||' => 1,
  '&&' => 2,
  '==' || '!=' => 3,
  '<' || '<=' || '>' || '>=' => 4,
  '+' || '-' => 5,
  '*' || '/' => 6,
  '^' => 8,
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

  _Token get _peek => _tokens[_pos];
  _Token _advance() => _tokens[_pos++];

  void _enterParen(int offset) {
    _parenDepth++;
    if (_parenDepth > expressionMaxDepth) {
      throw FormatException(
        'Expression is too deeply nested (more than $expressionMaxDepth '
        'levels of parentheses).',
      );
    }
  }

  _Expr parse() {
    if (_peek.kind == _TokenKind.eof) {
      throw const FormatException('Empty expression.');
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
        'Expression is too deeply nested (depth ${expr.depth} > '
        '$expressionMaxDepth).',
      );
    }
  }

  _Expr _parseExpr(int minPrecedence) {
    var left = _parsePrefix();
    while (true) {
      final tok = _peek;
      if (tok.kind != _TokenKind.op) break;
      final prec = _binaryPrecedence(tok.text);
      if (prec == null || prec < minPrecedence) break;
      _advance();
      // `^` is right-associative; all other binary operators are left-assoc.
      final nextMin = tok.text == '^' ? prec : prec + 1;
      final right = _parseExpr(nextMin);
      left = _Binary(tok.text, left, right);
      _checkDepth(left);
    }
    return left;
  }

  _Expr _parsePrefix() {
    final tok = _advance();
    switch (tok.kind) {
      case _TokenKind.number:
        return _Literal(tok.numberValue!);
      case _TokenKind.ident:
        if (_peek.kind == _TokenKind.lparen) {
          _enterParen(tok.offset);
          final call = _parseCall(tok.text, tok.offset);
          _parenDepth--;
          return call;
        }
        return _Variable(tok.text);
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
        if (tok.text == '-' || tok.text == '!') {
          // Unary minus / logical not bind tighter than + - * / but looser
          // than ^, so -x^2 parses as -(x^2).
          final operand = _parseExpr(7);
          final expr = _Unary(tok.text, operand);
          _checkDepth(expr);
          return expr;
        }
        throw FormatException(
          'Unexpected operator "${tok.text}" at offset ${tok.offset}.',
        );
      case _TokenKind.rparen:
      case _TokenKind.comma:
      case _TokenKind.eof:
        throw FormatException(
          'Unexpected "${tok.text}" at offset ${tok.offset}.',
        );
    }
  }

  _Expr _parseCall(String name, int offset) {
    _advance(); // consume '('
    if (name == 'if') {
      final cond = _parseExpr(0);
      _expectComma();
      final thenBranch = _parseExpr(0);
      _expectComma();
      final elseBranch = _parseExpr(0);
      _expectRparen();
      final expr = _If(cond, thenBranch, elseBranch);
      _checkDepth(expr);
      return expr;
    }
    if (!_functions.contains(name)) {
      throw FormatException('Unknown function "$name" at offset $offset.');
    }
    final arg = _parseExpr(0);
    _expectRparen();
    final expr = _Call(name, arg);
    _checkDepth(expr);
    return expr;
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
