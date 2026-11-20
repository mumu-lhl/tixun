/// Restricted expression language for TiXun Visual DSL v1.
///
/// A parsed expression is a small AST over doubles. The language supports
/// literals, variables (`x`, `t`, parameter names), `+ - * / ^` (`^` is
/// right-associative), unary minus and plus, parentheses, the functions
/// `sin cos tan asin acos atan sinh cosh tanh exp ln log sqrt abs floor ceil
/// sign`, `if(cond, a, b)` with `< <= > >= == != && || !`, and the constants
/// `pi` and `e`.
///
/// `log` is base-10 (`ln` is the natural log). Comparisons and logic return
/// `1.0` for true and `0.0` for false. `&&`, `||` and `if` are lazy: the
/// untaken branch is never evaluated, so `x != 0 && 1 / x > 2` is safe.
///
/// Nothing here executes generated code: parsing builds an AST and
/// [evaluate] walks it. AST depth is limited to 32 (see
/// [expressionMaxDepth]); a deeper expression throws [FormatException]
/// at parse time, which also bounds evaluation recursion. Parser
/// recursion itself is separately capped (see
/// [expressionMaxRecursionDepth]) so pathological chains fail with
/// [FormatException] instead of overflowing the stack before the AST
/// check runs.
library;

import "dart:math" as math;

part "expression_parser.dart";

/// Maximum AST depth (root = 1). A flat `a + b + c + ...` chain builds a
/// left-deep tree, so very long flat sums count against this limit too;
/// model-generated expressions are short, and the validator reports the
/// failure so the model can retry with a shorter form. Depth is stored in
/// each node at construction, so the check is O(1) and long inputs fail
/// fast instead of re-walking the tree on every parser step.
const expressionMaxDepth = 32;

/// Maximum parser recursion depth (entries into `_parseExpr` /
/// `_parsePrefix`). The AST depth check only runs after a subtree is
/// built, so without this guard a long unary-minus or right-associative
/// `^` chain could overflow the parser stack before the check ever
/// runs. Each descent level adds at most one AST level, so a legal
/// expression (AST depth ≤ 32) nests at most ~66 counted frames; 128
/// leaves roughly 2x headroom while staying orders of magnitude below
/// the stack-overflow threshold (thousands of frames).
const expressionMaxRecursionDepth = 128;

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

  /// Variable names that may actually be read when evaluating, given that
  /// the variables in [knownVars] have those values. `if`/`&&`/`||`
  /// branches whose condition folds to a constant under [knownVars]
  /// contribute only the branch that would run; a condition mentioning an
  /// unknown variable (e.g. `x`, `t`) is not foldable, so both branches
  /// count. This mirrors the lazy evaluation semantics: a dead branch
  /// never reads its variables, so the validator must not flag them.
  Set<String> variablesReachable(Map<String, double> knownVars) =>
      _root.variablesReachable(knownVars);

  @override
  String toString() => _root.toString();
}

sealed class _Expr {
  const _Expr({required this.depth, required this.offset});

  /// Depth of this subtree (root = 1), stored at construction so the
  /// depth check is O(1): computing it on demand would re-walk the whole
  /// subtree on every parser step (quadratic on long inputs).
  final int depth;

  /// Source offset of the token that produced this node, so eval-time
  /// errors can say where the offending value came from.
  final int offset;

  double eval(Map<String, double> vars);
  Set<String> get variables;

  /// Variable names that may be read when evaluating, given [knownVars].
  /// `if`/`&&`/`||` branches whose condition folds to a constant under
  /// [knownVars] contribute only the branch that would actually run.
  Set<String> variablesReachable(Map<String, double> knownVars);
}

/// Tries to evaluate [expr] with [knownVars]; returns null when the value
/// depends on an unknown variable (or is non-finite), i.e. the expression
/// cannot be folded to a constant here.
double? _tryFold(_Expr expr, Map<String, double> knownVars) {
  try {
    return expr.eval(knownVars);
  } on FormatException {
    return null;
  }
}

class _Literal extends _Expr {
  const _Literal(this.value, {required super.offset}) : super(depth: 1);

  final double value;

  @override
  double eval(Map<String, double> vars) => value;

  @override
  Set<String> get variables => const {};

  @override
  Set<String> variablesReachable(Map<String, double> knownVars) => const {};

  @override
  String toString() => value.toString();
}

class _Variable extends _Expr {
  const _Variable(this.name, {required super.offset}) : super(depth: 1);

  final String name;

  @override
  double eval(Map<String, double> vars) {
    final v = vars[name];
    if (v != null) return _finite(v, name, offset);
    if (name == "pi") return math.pi;
    if (name == "e") return math.e;
    throw FormatException('Unknown variable "$name" at offset $offset.');
  }

  @override
  Set<String> get variables => {name};

  @override
  Set<String> variablesReachable(Map<String, double> knownVars) => {name};

  @override
  String toString() => name;
}

class _Unary extends _Expr {
  _Unary(this.op, this.operand, {required super.offset})
    : super(depth: 1 + operand.depth);

  final String op;
  final _Expr operand;

  @override
  double eval(Map<String, double> vars) {
    final v = operand.eval(vars);
    final result = switch (op) {
      "-" => -v,
      "+" => v,
      _ => v == 0 ? 1.0 : 0.0,
    };
    return _finite(result, op, offset);
  }

  @override
  Set<String> get variables => operand.variables;

  @override
  Set<String> variablesReachable(Map<String, double> knownVars) =>
      operand.variablesReachable(knownVars);

  @override
  String toString() => "($op$operand)";
}

class _Binary extends _Expr {
  _Binary(this.op, this.left, this.right, {required super.offset})
    : super(depth: 1 + math.max(left.depth, right.depth));

  final String op;
  final _Expr left;
  final _Expr right;

  @override
  double eval(Map<String, double> vars) {
    // Short-circuit logic: the untaken branch is never evaluated.
    if (op == "&&") {
      if (left.eval(vars) == 0) return 0;
      return right.eval(vars) == 0 ? 0 : 1;
    }
    if (op == "||") {
      if (left.eval(vars) != 0) return 1;
      return right.eval(vars) == 0 ? 0 : 1;
    }
    final l = left.eval(vars);
    final r = right.eval(vars);
    final result = switch (op) {
      "+" => l + r,
      "-" => l - r,
      "*" => l * r,
      "/" => l / r,
      "^" => math.pow(l, r).toDouble(),
      "<" => l < r ? 1.0 : 0.0,
      "<=" => l <= r ? 1.0 : 0.0,
      ">" => l > r ? 1.0 : 0.0,
      ">=" => l >= r ? 1.0 : 0.0,
      "==" => l == r ? 1.0 : 0.0,
      "!=" => l != r ? 1.0 : 0.0,
      _ => throw FormatException('Unknown operator "$op".'),
    };
    return _finite(result, op, offset);
  }

  @override
  Set<String> get variables => {...left.variables, ...right.variables};

  @override
  Set<String> variablesReachable(Map<String, double> knownVars) {
    if (op == "&&") {
      final folded = _tryFold(left, knownVars);
      if (folded != null && folded == 0) {
        return left.variablesReachable(knownVars);
      }
    } else if (op == "||") {
      final folded = _tryFold(left, knownVars);
      if (folded != null && folded != 0) {
        return left.variablesReachable(knownVars);
      }
    }
    return {
      ...left.variablesReachable(knownVars),
      ...right.variablesReachable(knownVars),
    };
  }

  @override
  String toString() => "($left $op $right)";
}

class _Call extends _Expr {
  _Call(this.name, this.arg, {required super.offset})
    : super(depth: 1 + arg.depth);

  final String name;
  final _Expr arg;

  @override
  double eval(Map<String, double> vars) {
    final v = arg.eval(vars);
    final result = switch (name) {
      "sin" => math.sin(v),
      "cos" => math.cos(v),
      "tan" => math.tan(v),
      "asin" => math.asin(v),
      "acos" => math.acos(v),
      "atan" => math.atan(v),
      "sinh" => _sinh(v),
      "cosh" => _cosh(v),
      "tanh" => _tanh(v),
      "exp" => math.exp(v),
      "ln" => math.log(v),
      "log" => math.log(v) / math.ln10,
      "sqrt" => math.sqrt(v),
      "abs" => v.abs(),
      "floor" => v.floorToDouble(),
      "ceil" => v.ceilToDouble(),
      "sign" => v == 0 ? 0.0 : (v > 0 ? 1.0 : -1.0),
      _ => throw FormatException('Unknown function "$name".'),
    };
    return _finite(result, name, offset);
  }

  @override
  Set<String> get variables => arg.variables;

  @override
  Set<String> variablesReachable(Map<String, double> knownVars) =>
      arg.variablesReachable(knownVars);

  @override
  String toString() => "$name($arg)";
}

class _If extends _Expr {
  _If(this.cond, this.thenBranch, this.elseBranch, {required super.offset})
    : super(
        depth:
            1 +
            math.max(cond.depth, math.max(thenBranch.depth, elseBranch.depth)),
      );

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
  Set<String> variablesReachable(Map<String, double> knownVars) {
    final condVars = cond.variablesReachable(knownVars);
    final folded = _tryFold(cond, knownVars);
    if (folded != null) {
      // The condition is constant here: only the taken branch can run.
      return {
        ...condVars,
        ...(folded != 0
            ? thenBranch.variablesReachable(knownVars)
            : elseBranch.variablesReachable(knownVars)),
      };
    }
    return {
      ...condVars,
      ...thenBranch.variablesReachable(knownVars),
      ...elseBranch.variablesReachable(knownVars),
    };
  }

  @override
  String toString() => "if($cond, $thenBranch, $elseBranch)";
}

double _finite(double value, String where, int offset) {
  if (!value.isFinite) {
    throw FormatException(
      'Non-finite result while evaluating "$where" at offset $offset.',
    );
  }
  return value;
}

/// sinh/cosh via the factored form for large |v|: `exp(v)` overflows a
/// double past ln(double.max) ≈ 709.78, but sinh/cosh themselves stay
/// finite up to |v| ≈ 710.47, so factor out exp(|v|)/2 and evaluate
/// exp(|v| - ln 2) instead. Below the threshold the direct form is used.
double _sinh(double v) {
  final a = v.abs();
  if (a > 709.0) {
    final scaled = math.exp(a - math.ln2) * (1 - math.exp(-2 * a));
    return v < 0 ? -scaled : scaled;
  }
  return (math.exp(v) - math.exp(-v)) / 2;
}

double _cosh(double v) {
  final a = v.abs();
  if (a > 709.0) {
    return math.exp(a - math.ln2) * (1 + math.exp(-2 * a));
  }
  return (math.exp(v) + math.exp(-v)) / 2;
}

double _tanh(double v) {
  // tanh(20) is already 1.0 to within one double ulp, so saturating
  // here is exact; the (e^2v - 1) / (e^2v + 1) form below overflows
  // to NaN once 2v passes ln(double.max).
  if (v.abs() > 20) return v < 0 ? -1.0 : 1.0;
  final e2 = math.exp(2 * v);
  return (e2 - 1) / (e2 + 1);
}

const _functions = {
  "sin",
  "cos",
  "tan",
  "asin",
  "acos",
  "atan",
  "sinh",
  "cosh",
  "tanh",
  "exp",
  "ln",
  "log",
  "sqrt",
  "abs",
  "floor",
  "ceil",
  "sign",
};
