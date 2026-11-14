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

    test('a steep model zero is NOT flagged as derived_mismatch', () {
      // Bisection refines the zero to ~5e-10 in x; with slope 1e9 the
      // re-evaluated |f| is ~0.5. That is far above the old absolute
      // 1e-6 tolerance, but nothing is wrong: the zero is right, the
      // slope is just steep. The tolerance is now relative to the
      // function's own scale, so steep slopes no longer false-positive.
      final scene = _scene(_plot('1e9*(x-0.5)', alt: '陡峭直线'));
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), isNot(contains('derived_mismatch')));
    });

    test('the review probe input is NOT flagged as derived_mismatch', () {
      // f = 1e6*(x-0.123456789): the zero re-evaluates to a residual
      // of 2.85e-4, above the old absolute tolerance — a false
      // positive the relative tolerance removes.
      final scene = _scene(_plot('1e6*(x-0.123456789)', alt: '陡峭直线'));
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), isNot(contains('derived_mismatch')));
    });

    test('a narrow defined window is visible at canvas resolution', () {
      // sqrt((x-0.506)*(0.516-x)) is defined only on [0.506, 0.516]:
      // the 256-sample grid has no point in the window, the
      // 1024-sample grid has two. The quality check samples at the
      // canvas resolution, so it agrees with the renderer that the
      // curve is visible.
      final scene = _scene(_plot('sqrt((x-0.506)*(0.516-x))', alt: '窄窗'));
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), isNot(contains('curve_not_visible')));
    });

    test('a plot element is checked at its own sample count', () {
      // The same narrow window as a plot element with samples: 256:
      // the canvas draws it with 256 samples, which miss the window
      // entirely, so the check must agree it is not visible.
      final scene = _scene({
        'v': 1,
        'kind': 'plot2d',
        'title': '窄窗',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'plot',
            'expression': 'sqrt((x-0.506)*(0.516-x))',
            'domain': [-3, 3],
            'samples': 256,
          },
        ],
        'meta': {'alt': '窄窗'},
      });
      final issues = checkVisualQuality(scene);
      final flagged = issues
          .where((i) => i.code == 'curve_not_visible')
          .toList();
      expect(flagged, hasLength(1));
      expect(flagged.single.path, 'p1');
    });

    test('a scene with only annotations is not empty', () {
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '注',
        'annotations': [
          {
            'at': [0, 0],
            'text': '说明',
          },
        ],
        'meta': {'alt': '注'},
      });
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), isNot(contains('empty_scene')));
    });

    test('a circle reaching into the view from outside is not flagged', () {
      // Centre (5, 0) is outside [-3, 3]^2, but radius 3 reaches x = 2.
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '圆',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'c1',
            'type': 'circle',
            'center': [5, 0],
            'r': 3,
          },
        ],
        'meta': {'alt': '圆'},
      });
      expect(checkVisualQuality(scene), isEmpty);
    });

    test('a circle fully outside the view is flagged', () {
      // Centre (5, 0), radius 1: extent x in [4, 6], entirely outside.
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '圆',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'c1',
            'type': 'circle',
            'center': [5, 0],
            'r': 1,
          },
        ],
        'meta': {'alt': '圆'},
      });
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), ['point_outside_view']);
      expect(issues.single.path, 'c1');
    });

    test('an arc reaching into the view from outside is not flagged', () {
      // Centre (5, 0), radius 3, sweep 180°→270°: the arc runs from
      // (2, 0) to (5, -3), reaching into the view.
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '弧',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'a1',
            'type': 'arc',
            'center': [5, 0],
            'r': 3,
            'startDeg': 180,
            'sweepDeg': 90,
          },
        ],
        'meta': {'alt': '弧'},
      });
      expect(checkVisualQuality(scene), isEmpty);
    });

    test('an arc fully outside the view is flagged', () {
      // Centre (5, 0), radius 1, sweep 0°→90°: arc points x in [5, 6].
      final scene = _scene({
        'v': 1,
        'kind': 'geometry',
        'title': '弧',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'a1',
            'type': 'arc',
            'center': [5, 0],
            'r': 1,
            'startDeg': 0,
            'sweepDeg': 90,
          },
        ],
        'meta': {'alt': '弧'},
      });
      final issues = checkVisualQuality(scene);
      expect(issues.map((i) => i.code), ['point_outside_view']);
      expect(issues.single.path, 'a1');
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
