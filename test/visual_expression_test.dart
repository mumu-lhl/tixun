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
      final deepParens = '${'(' * 40}1${')' * 40}';
      expect(() => Expression.parse(deepParens), throwsFormatException);
      final deepUnary = '${'-' * 40}x';
      expect(() => Expression.parse(deepUnary), throwsFormatException);
      // Just inside the limit parses fine.
      expect(Expression.parse('${'(' * 20}1+2${')' * 20}').evaluate({}), 3);
    });
  });

  test('variables collects referenced names', () {
    expect(Expression.parse('a*x+sin(y)').variables, {'a', 'x', 'y'});
    expect(Expression.parse('pi*2').variables, {'pi'});
    expect(Expression.parse('if(t>0,1,0)').variables, {'t'});
  });
}
