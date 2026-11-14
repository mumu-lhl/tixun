import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/math/sampling.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/validation/visual_quality.dart';

VisualScene _scene(Map<String, dynamic> json) => VisualScene.fromJson(json);

Map<String, dynamic> _plot(
  String expression, {
  List<double>? viewX,
  List<double>? viewY,
  String? alt,
  String? title,
}) => {
  'v': 1,
  'kind': 'plot2d',
  'title': ?title,
  'model': {'expression': expression},
  'view': {
    'x': viewX ?? [-3, 3],
    'y': viewY ?? [-5, 6],
  },
  if (alt != null) 'meta': {'alt': alt},
};

void main() {
  group('math-correctness corpus (plan 14.2)', () {
    test('x^2-4: zeros at +-2, minimum at (0, -4)', () {
      final zeros = findZeros('x^2-4', const {}, -3, 3);
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-6));
      expect(zeros[1], closeTo(2, 1e-6));
      final extrema = findExtrema('x^2-4', const {}, -3, 3);
      expect(extrema, hasLength(1));
      expect(extrema[0].x, closeTo(0, 1e-6));
      expect(extrema[0].y, closeTo(-4, 1e-6));
      expect(extrema[0].kind, 'min');
    });

    test('sin(x) on [-2, 2]: one zero, extrema at +-pi/2', () {
      final zeros = findZeros('sin(x)', const {}, -2, 2);
      expect(zeros, hasLength(1));
      expect(zeros[0], closeTo(0, 1e-6));
      final extrema = findExtrema('sin(x)', const {}, -2, 2);
      expect(extrema, hasLength(2));
      expect(extrema[0].x, closeTo(-math.pi / 2, 1e-4));
      expect(extrema[0].kind, 'min');
      expect(extrema[1].x, closeTo(math.pi / 2, 1e-4));
      expect(extrema[1].kind, 'max');
    });

    test(
      'x^3-3x: zeros at 0 and +-sqrt(3), extrema at (-1, 2) and (1, -2)',
      () {
        final zeros = findZeros('x^3-3*x', const {}, -3, 3);
        expect(zeros, hasLength(3));
        expect(zeros[0], closeTo(-math.sqrt(3), 1e-6));
        expect(zeros[1], closeTo(0, 1e-6));
        expect(zeros[2], closeTo(math.sqrt(3), 1e-6));
        final extrema = findExtrema('x^3-3*x', const {}, -3, 3);
        expect(extrema, hasLength(2));
        expect(extrema[0].x, closeTo(-1, 1e-4));
        expect(extrema[0].y, closeTo(2, 1e-4));
        expect(extrema[0].kind, 'max');
        expect(extrema[1].x, closeTo(1, 1e-4));
        expect(extrema[1].y, closeTo(-2, 1e-4));
        expect(extrema[1].kind, 'min');
      },
    );

    test('2x+1: one zero, no extrema', () {
      expect(findZeros('2*x+1', const {}, -3, 3), [closeTo(-0.5, 1e-6)]);
      expect(findExtrema('2*x+1', const {}, -3, 3), isEmpty);
    });

    test('computeDerivedValues reproduces the corpus for x^2-4', () {
      final scene = _scene(_plot('x^2-4', alt: '抛物线'));
      final derived = computeDerivedValues(scene);
      expect((derived['zeros'] as List).cast<double>(), [
        closeTo(-2, 1e-6),
        closeTo(2, 1e-6),
      ]);
      final extrema = (derived['extrema'] as List).cast<Map>();
      expect(extrema, hasLength(1));
      expect(extrema[0]['x'] as num, closeTo(0, 1e-6));
      expect(extrema[0]['y'] as num, closeTo(-4, 1e-6));
      expect(derived.containsKey('errors'), isFalse);
    });
  });

  group('checkVisualQuality', () {
    test('a clean scene has no issues', () {
      final scene = _scene(_plot('x^2-4', alt: '抛物线'));
      expect(checkVisualQuality(scene), isEmpty);
    });

    test('missing alt and title is flagged', () {
      final scene = _scene(_plot('x^2-4'));
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), contains('missing_alt'));
      // A title alone is enough of a text alternative.
      final withTitle = _scene(_plot('x^2-4', title: '抛物线'));
      expect(checkVisualQuality(withTitle), isEmpty);
    });

    test('a point outside the declared view is flagged', () {
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '点',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'point',
            'at': [5, 5],
            'label': 'P',
          },
          {
            'id': 'p2',
            'type': 'point',
            'at': [0, 0],
          },
        ],
        'meta': {'alt': '点'},
      });
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), ['point_outside_view']);
      expect(issues.single.path, 'p1');
      expect(issues.single.message, contains('5'));
    });

    test('a curve with no visible samples is flagged', () {
      // sqrt(x) is undefined everywhere on [-3, -1].
      final scene = _scene(
        _plot('sqrt(x)', viewX: [-3, -1], viewY: [-3, 3], alt: '根号'),
      );
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), contains('curve_not_visible'));
    });

    test('a plot element with no visible samples is flagged with its id', () {
      // Same invisible curve, but as a plot element: the issue must
      // carry the element id as its path, not the model path.
      final scene = _scene({
        'v': 1,
        'kind': 'plot2d',
        'title': '根号',
        'view': {
          'x': [-3, -1],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'plot',
            'expression': 'sqrt(x)',
            'domain': [-3, -1],
          },
        ],
        'meta': {'alt': '根号'},
      });
      final issues = checkVisualQuality(scene);
      final flagged = issues
          .where((i) => i.code == 'curve_not_visible')
          .toList();
      expect(flagged, hasLength(1));
      expect(flagged.single.path, 'p1');
    });

    test('a steep model zero is flagged as derived_mismatch', () {
      // Bisection refines the zero to ~5e-10 in x; with slope 1e9 the
      // re-evaluated |f| is ~0.5, far above the 1e-6 check tolerance,
      // so the reported zero does not reproduce the curve.
      final scene = _scene(_plot('1e9*(x-0.5)', alt: '陡峭直线'));
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), contains('derived_mismatch'));
    });

    test('tan(x) has no derived_mismatch: poles are not zeros', () {
      // The only zero on [-3, 3] is x = 0, where tan is exactly 0.
      // Before the pole guard in findZeros, the poles at ±pi/2 were
      // reported as zeros and re-evaluated to huge values, which
      // falsely flagged derived_mismatch here.
      final scene = _scene(_plot('tan(x)', alt: '正切'));
      expect(checkVisualQuality(scene), isEmpty);
    });

    test('a scene with nothing in it is flagged', () {
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '空',
        'elements': <dynamic>[],
        'meta': {'alt': '空'},
      });
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), contains('empty_scene'));
    });
  });
}
