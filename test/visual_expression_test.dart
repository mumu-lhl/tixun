import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/math/expression.dart';

void main() {
  group('Expression.evaluate', () {
    test('operator precedence', () {
      expect(Expression.parse('2+3*4').evaluate({}), 14);
      expect(Expression.parse('(2+3)*4').evaluate({}), 20);
      expect(Expression.parse('10-4-3').evaluate({}), 3);
      expect(Expression.parse('2*3^2').evaluate({}), 18);
      expect(Expression.parse('10/4').evaluate({}), 2.5);
    });

    test('^ is right-associative', () {
      expect(Expression.parse('2^3^2').evaluate({}), 512);
      expect(Expression.parse('(2^3)^2').evaluate({}), 64);
    });

    test('unary minus binds looser than ^', () {
      expect(Expression.parse('-2^2').evaluate({}), -4);
      expect(Expression.parse('(-2)^2').evaluate({}), 4);
      expect(Expression.parse('2*-3').evaluate({}), -6);
      expect(Expression.parse('--5').evaluate({}), 5);
    });

    test('functions', () {
      expect(Expression.parse('sin(pi/2)').evaluate({}), closeTo(1, 1e-12));
      expect(Expression.parse('cos(0)').evaluate({}), 1);
      expect(Expression.parse('tan(0)').evaluate({}), 0);
      expect(Expression.parse('sqrt(16)').evaluate({}), 4);
      expect(Expression.parse('abs(-3)').evaluate({}), 3);
      expect(Expression.parse('ln(e)').evaluate({}), closeTo(1, 1e-12));
      expect(Expression.parse('log(100)').evaluate({}), closeTo(2, 1e-12));
      expect(Expression.parse('log(1000)').evaluate({}), closeTo(3, 1e-12));
      expect(Expression.parse('exp(0)').evaluate({}), 1);
      expect(Expression.parse('floor(1.7)').evaluate({}), 1);
      expect(Expression.parse('ceil(1.2)').evaluate({}), 2);
      expect(Expression.parse('sign(-5)').evaluate({}), -1);
      expect(Expression.parse('sign(0)').evaluate({}), 0);
      expect(Expression.parse('sign(7)').evaluate({}), 1);
      expect(
        Expression.parse('asin(1)').evaluate({}),
        closeTo(3.141592653589793 / 2, 1e-12),
      );
      expect(Expression.parse('sinh(0)').evaluate({}), 0);
      expect(Expression.parse('cosh(0)').evaluate({}), 1);
      expect(Expression.parse('tanh(0)').evaluate({}), 0);
    });

    test('tanh saturates to +-1 for large |v|', () {
      expect(Expression.parse('tanh(355)').evaluate({}), 1);
      expect(Expression.parse('tanh(400)').evaluate({}), 1);
      expect(Expression.parse('tanh(-400)').evaluate({}), -1);
      expect(Expression.parse('tanh(21)').evaluate({}), 1);
      expect(Expression.parse('tanh(1000)').evaluate({}), 1);
    });

    test('sinh/cosh stay finite past exp overflow', () {
      // exp(710) overflows a double, but sinh(710) = cosh(710) =
      // e^710 / 2 ≈ 1.1169973830808555e308 is still finite. The factored
      // form evaluates exp(710 - ln 2), whose argument rounding costs
      // ~5e-14 relative, so the tolerance is 1e-12 relative.
      final sinh710 = Expression.parse('sinh(710)').evaluate({});
      expect(sinh710.isFinite, isTrue);
      expect(sinh710, closeTo(1.1169973830808555e308, 1e296));
      final cosh710 = Expression.parse('cosh(710)').evaluate({});
      expect(cosh710.isFinite, isTrue);
      expect(cosh710, closeTo(1.1169973830808555e308, 1e296));
    });

    test('variables and parameters', () {
      expect(Expression.parse('x^2').evaluate({'x': 3}), 9);
      expect(Expression.parse('a*x+1').evaluate({'a': 2, 'x': 3}), 7);
      expect(Expression.parse('t*2').evaluate({'t': 4}), 8);
      expect(Expression.parse('pi').evaluate({}), 3.141592653589793);
      expect(Expression.parse('e').evaluate({}), 2.718281828459045);
    });

    test('comparisons and logic return 1.0 / 0.0', () {
      expect(Expression.parse('1<2').evaluate({}), 1);
      expect(Expression.parse('2<=2').evaluate({}), 1);
      expect(Expression.parse('3>4').evaluate({}), 0);
      expect(Expression.parse('3>=4').evaluate({}), 0);
      expect(Expression.parse('1==1').evaluate({}), 1);
      expect(Expression.parse('1!=1').evaluate({}), 0);
      expect(Expression.parse('!0').evaluate({}), 1);
      expect(Expression.parse('!5').evaluate({}), 0);
      expect(Expression.parse('1 && 0').evaluate({}), 0);
      expect(Expression.parse('1 || 0').evaluate({}), 1);
      expect(Expression.parse('2 > 1 && 3 > 2').evaluate({}), 1);
    });

    test('if(cond, a, b)', () {
      expect(Expression.parse('if(x>0,1,-1)').evaluate({'x': 5}), 1);
      expect(Expression.parse('if(x>0,1,-1)').evaluate({'x': -5}), -1);
      expect(Expression.parse('if(x>0 && x<10, 1, 0)').evaluate({'x': 5}), 1);
      expect(Expression.parse('if(x>0 && x<10, 1, 0)').evaluate({'x': 50}), 0);
      expect(Expression.parse('if(x>=0,x,-x)').evaluate({'x': -3}), 3);
    });

    test('&& and || short-circuit past division by zero', () {
      expect(Expression.parse('x != 0 && 1/x > 2').evaluate({'x': 0}), 0);
      expect(Expression.parse('x == 0 || 1/x > 2').evaluate({'x': 0}), 1);
    });

    test('scientific notation and decimals', () {
      expect(Expression.parse('1e3+1').evaluate({}), 1001);
      expect(Expression.parse('.5*2').evaluate({}), 1);
      expect(Expression.parse('0.1+0.2').evaluate({}), closeTo(0.3, 1e-12));
    });
  });

  group('Expression.parse errors', () {
    test('unknown variable throws FormatException', () {
      expect(() => Expression.parse('y+1').evaluate({}), throwsFormatException);
      expect(
        () => Expression.parse('y+1').evaluate({'x': 1}),
        throwsFormatException,
      );
    });

    test('non-finite results throw FormatException', () {
      expect(() => Expression.parse('1/0').evaluate({}), throwsFormatException);
      expect(
        () => Expression.parse('sqrt(-1)').evaluate({}),
        throwsFormatException,
      );
      expect(
        () => Expression.parse('ln(0)').evaluate({}),
        throwsFormatException,
      );
      expect(
        () => Expression.parse('0^ -1').evaluate({}),
        throwsFormatException,
      );
    });

    test('sinh/cosh past their own range still throw FormatException', () {
      // sinh(1000) itself exceeds double.max, so it must still fail.
      expect(
        () => Expression.parse('sinh(1000)').evaluate({}),
        throwsFormatException,
      );
      expect(
        () => Expression.parse('cosh(1000)').evaluate({}),
        throwsFormatException,
      );
    });

    test('syntax errors throw FormatException', () {
      for (final bad in [
        '',
        '   ',
        '2+',
        '(2+3',
        '2^^3',
        'sin(1,2)',
        'sin()',
        'foo(1)',
        'if(x>0,1)',
        'if(x>0,1,2,3)',
        '2 & 3',
        'x = 1',
        '1e999',
        '@',
      ]) {
        expect(
          () => Expression.parse(bad),
          throwsFormatException,
          reason: 'expected "$bad" to fail',
        );
      }
    });

    test('AST depth limit 32', () {
      // Parentheses do not create AST nodes, so the paren cap follows
      // the parser recursion budget (128 frames, two per paren level
      // plus two for the innermost literal: 63 fit), not the AST depth
      // limit (32): 40 parens around a literal is only one AST level
      // deep.
      expect(Expression.parse('${'(' * 40}1${')' * 40}').evaluate({}), 1);
      expect(Expression.parse('${'(' * 63}1${')' * 63}').evaluate({}), 1);
      expect(
        () => Expression.parse('${'(' * 64}1${')' * 64}'),
        throwsFormatException,
      );
      final deepUnary = '${'-' * 40}x';
      expect(() => Expression.parse(deepUnary), throwsFormatException);
      // Just inside the limit parses fine.
      expect(Expression.parse('${'(' * 20}1+2${')' * 20}').evaluate({}), 3);
    });

    test('flat sums count against the AST depth limit', () {
      // A flat `1+1+...` chain builds a left-deep tree, so 33 terms
      // exceed depth 32 even though the expression is "flat".
      expect(
        () => Expression.parse(List.filled(33, '1').join('+')),
        throwsFormatException,
      );
      expect(Expression.parse(List.filled(32, '1').join('+')).evaluate({}), 32);
      // A balanced sum of the same size stays shallow and parses:
      // depth is stored per node, so the check is a single pass.
      String balanced(int n) {
        if (n == 1) return '1';
        final half = n ~/ 2;
        return '(${balanced(half)}+${balanced(n - half)})';
      }

      expect(Expression.parse(balanced(16000)).evaluate({}), 16000);
    });

    test('very long unary / ^ chains throw FormatException, not StackOverflowError', () {
      // The AST depth check only runs after a subtree is built, so
      // without a descent guard these overflow the parser stack.
      expect(() => Expression.parse('${'-' * 5000}x'), throwsFormatException);
      expect(() => Expression.parse('${'2^' * 20000}2'), throwsFormatException);
    });
  });

  test('variables collects referenced names', () {
    expect(Expression.parse('a*x+sin(y)').variables, {'a', 'x', 'y'});
    expect(Expression.parse('pi*2').variables, {'pi'});
    expect(Expression.parse('if(t>0,1,0)').variables, {'t'});
  });

  group('Expression.evaluate: unary plus and log base', () {
    test('unary plus is a no-op', () {
      expect(Expression.parse('+5').evaluate({}), 5);
      expect(Expression.parse('2++3').evaluate({}), 5);
      expect(Expression.parse('2+-3').evaluate({}), -1);
      expect(Expression.parse('+(2*3)').evaluate({}), 6);
      expect(Expression.parse('+x').evaluate({'x': 7}), 7);
    });

    test('log is base-10, ln is the natural log', () {
      expect(Expression.parse('log(100)').evaluate({}), closeTo(2, 1e-12));
      expect(Expression.parse('log(10)').evaluate({}), closeTo(1, 1e-12));
      expect(Expression.parse('ln(e)').evaluate({}), closeTo(1, 1e-12));
      expect(
        Expression.parse('ln(100)').evaluate({}),
        closeTo(4.605170185988092, 1e-12),
      );
    });

    test('0^0 is 1; a negative base to a fractional power throws', () {
      expect(Expression.parse('0^0').evaluate({}), 1);
      expect(
        () => Expression.parse('(-8)^(1/3)').evaluate({}),
        throwsFormatException,
      );
    });
  });

  group('Expression.parse errors: messages name the problem', () {
    String messageOf(void Function() f) {
      try {
        f();
      } on FormatException catch (e) {
        return e.message;
      }
      fail('expected a FormatException');
    }

    test('missing operand after an operator', () {
      expect(
        messageOf(() => Expression.parse('2+')),
        contains('Expected an operand'),
      );
    });

    test('malformed exponent is a bad number, not an identifier', () {
      expect(
        messageOf(() => Expression.parse('1e')),
        contains('Invalid number'),
      );
      expect(
        messageOf(() => Expression.parse('1e+')),
        contains('Invalid number'),
      );
      expect(
        messageOf(() => Expression.parse('1e+x')),
        contains('Invalid number'),
      );
    });

    test('too many function arguments name the arity', () {
      expect(
        messageOf(() => Expression.parse('sin(1,2)')),
        contains('takes exactly 1 argument'),
      );
      expect(
        messageOf(() => Expression.parse('if(1,2,3,4)')),
        contains('takes exactly 3 arguments'),
      );
    });

    test('a bare function name is not a variable', () {
      expect(
        messageOf(() => Expression.parse('sin')),
        contains('needs arguments'),
      );
      expect(
        messageOf(() => Expression.parse('if')),
        contains('needs arguments'),
      );
      expect(
        messageOf(() => Expression.parse('sin+1')),
        contains('needs arguments'),
      );
    });

    test('eval-time errors carry the source offset', () {
      expect(
        messageOf(() => Expression.parse('y+1').evaluate({})),
        contains('at offset 0'),
      );
      expect(
        messageOf(() => Expression.parse('1e308*10').evaluate({})),
        contains('at offset 5'),
      );
    });
  });

  group('Expression.variablesReachable respects laziness', () {
    test('a dead if branch contributes no variables', () {
      final expr = Expression.parse('if(a==0, 0, y)');
      expect(expr.variablesReachable({'a': 0}), {'a'});
      expect(expr.variablesReachable({'a': 1}), {'a', 'y'});
      expect(expr.variablesReachable({}), {'a', 'y'});
      // `x` is not foldable (it varies), so both branches count.
      expect(Expression.parse('if(x==0, 0, y)').variablesReachable({}), {
        'x',
        'y',
      });
      expect(Expression.parse('if(1, 0, y)').variablesReachable({}), isEmpty);
    });

    test('short-circuit logic skips the untaken side', () {
      expect(Expression.parse('0 && y').variablesReachable({}), isEmpty);
      expect(Expression.parse('1 || y').variablesReachable({}), isEmpty);
      expect(Expression.parse('1 && y').variablesReachable({}), {'y'});
      expect(Expression.parse('x!=0 && 1/x > 2').variablesReachable({'x': 0}), {
        'x',
      });
    });
  });
}
