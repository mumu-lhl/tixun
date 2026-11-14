import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/math/sampling.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';

void main() {
  group('sampleFunction', () {
    test('tan(x) splits at both asymptotes over [-4, 4]', () {
      final segments = sampleFunction('tan(x)', variables: {}, min: -4, max: 4);
      expect(segments.length, greaterThanOrEqualTo(3));
      for (final asymptote in [-math.pi / 2, math.pi / 2]) {
        for (final segment in segments) {
          final left = segment.points.any((p) => p.dx < asymptote);
          final right = segment.points.any((p) => p.dx > asymptote);
          expect(
            left && right,
            isFalse,
            reason: 'no segment may span the asymptote at $asymptote',
          );
        }
      }
    });

    test('1/(x-1) splits at x=1', () {
      final segments = sampleFunction(
        '1/(x-1)',
        variables: {},
        min: -2,
        max: 2,
      );
      expect(segments.length, greaterThanOrEqualTo(2));
      for (final segment in segments) {
        final left = segment.points.any((p) => p.dx < 1);
        final right = segment.points.any((p) => p.dx > 1);
        expect(left && right, isFalse);
      }
    });

    test('piecewise if(x>=0, x, -x) samples |x| on both sides', () {
      final segments = sampleFunction(
        'if(x>=0, x, -x)',
        variables: {},
        min: -2,
        max: 2,
      );
      expect(segments, hasLength(1));
      final points = segments.single.points;
      expect(points.first.dx, closeTo(-2, 1e-9));
      expect(points.first.dy, closeTo(2, 1e-9));
      expect(points.last.dx, closeTo(2, 1e-9));
      expect(points.last.dy, closeTo(2, 1e-9));
      for (final p in points) {
        expect(p.dy, closeTo(p.dx.abs(), 1e-9));
      }
      final nearZero = points.reduce((a, b) => a.dx.abs() < b.dx.abs() ? a : b);
      // 0 is not on the uniform grid; the nearest sample is within half a
      // step (~0.002) of it.
      expect(nearZero.dy, closeTo(0, 0.005));
    });

    test('parameter substitution: a*x with a=3', () {
      final segments = sampleFunction(
        'a*x',
        variables: {'a': 3},
        min: -1,
        max: 1,
      );
      expect(segments, hasLength(1));
      final points = segments.single.points;
      expect(points.first.dx, closeTo(-1, 1e-9));
      expect(points.first.dy, closeTo(-3, 1e-9));
      expect(points.last.dx, closeTo(1, 1e-9));
      expect(points.last.dy, closeTo(3, 1e-9));
    });

    test('caller-supplied x is overwritten by the sweep', () {
      final segments = sampleFunction(
        'a*x',
        variables: {'a': 3, 'x': 999},
        min: -1,
        max: 1,
      );
      expect(segments, hasLength(1));
      expect(segments.single.points.last.dy, closeTo(3, 1e-9));
    });

    test('total points respect maxSamples', () {
      for (final expr in ['sin(x)', 'tan(x)']) {
        final segments = sampleFunction(
          expr,
          variables: {},
          min: -10,
          max: 10,
          maxSamples: 100,
        );
        final total = segments.fold<int>(0, (sum, s) => sum + s.points.length);
        expect(total, lessThanOrEqualTo(100));
      }
    });

    test('empty range throws ArgumentError', () {
      expect(
        () => sampleFunction('x', variables: {}, min: 1, max: 1),
        throwsArgumentError,
      );
      expect(
        () => sampleFunction('x', variables: {}, min: 2, max: 1),
        throwsArgumentError,
      );
    });

    test('maxSamples above the hard cap throws ArgumentError', () {
      expect(
        () => sampleFunction(
          'x',
          variables: {},
          min: 0,
          max: 1,
          maxSamples: 4097,
        ),
        throwsArgumentError,
      );
    });

    test('unparseable expression throws FormatException', () {
      expect(
        () => sampleFunction('x + (', variables: {}, min: 0, max: 1),
        throwsFormatException,
      );
    });
  });

  group('findZeros', () {
    test('x^2-4 has zeros exactly [-2, 2]', () {
      final zeros = findZeros('x^2-4', {}, -3, 3);
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-9));
      expect(zeros[1], closeTo(2, 1e-9));
    });

    test('x^2+1 has no zeros', () {
      expect(findZeros('x^2+1', {}, -3, 3), isEmpty);
    });

    test('exact hit at a grid point is caught', () {
      // x^2 touches zero at 0 without a sign change; 0 is on the grid.
      expect(findZeros('x^2', {}, -2, 2), [closeTo(0, 1e-9)]);
    });
  });

  group('findIntersections', () {
    test('x^2 and 2x meet at (0,0) and (2,4)', () {
      final points = findIntersections('x^2', '2*x', {}, -3, 3);
      expect(points, hasLength(2));
      expect(points[0].dx, closeTo(0, 1e-6));
      expect(points[0].dy, closeTo(0, 1e-6));
      expect(points[1].dx, closeTo(2, 1e-6));
      expect(points[1].dy, closeTo(4, 1e-6));
    });

    test('parallel lines have no intersections', () {
      expect(findIntersections('x', 'x+1', {}, -3, 3), isEmpty);
    });
  });

  group('findExtrema', () {
    test('x^2 has one minimum at (0,0)', () {
      final extrema = findExtrema('x^2', {}, -2, 2);
      expect(extrema, hasLength(1));
      expect(extrema.single.kind, 'min');
      expect(extrema.single.x, closeTo(0, 1e-6));
      expect(extrema.single.y, closeTo(0, 1e-6));
    });

    test('-x^2 has one maximum at (0,0)', () {
      final extrema = findExtrema('-x^2', {}, -2, 2);
      expect(extrema, hasLength(1));
      expect(extrema.single.kind, 'max');
      expect(extrema.single.x, closeTo(0, 1e-6));
      expect(extrema.single.y, closeTo(0, 1e-6));
    });

    test('sin has a max and a min over [-pi, pi]', () {
      final extrema = findExtrema('sin(x)', {}, -math.pi, math.pi);
      expect(extrema, hasLength(2));
      expect(extrema[0].kind, 'min');
      expect(extrema[0].x, closeTo(-math.pi / 2, 1e-6));
      expect(extrema[1].kind, 'max');
      expect(extrema[1].x, closeTo(math.pi / 2, 1e-6));
    });

    test('monotone function has no extrema', () {
      expect(findExtrema('x^3', {}, -2, 2), isEmpty);
    });
  });

  group('computeDerivedValues', () {
    test('design-note example scene returns zeros [-2, 2]', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'model': {'expression': 'x^2-4'},
        'view': {
          'x': [-3, 3],
          'y': [-5, 6],
        },
      });
      final values = computeDerivedValues(scene);
      final zeros = values['zeros'] as List;
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-9));
      expect(zeros[1], closeTo(2, 1e-9));
      final extrema = values['extrema'] as List;
      expect(extrema, hasLength(1));
      final min = extrema.single as Map;
      expect(min['kind'], 'min');
      expect(min['x'], closeTo(0, 1e-6));
      expect(min['y'], closeTo(-4, 1e-6));
      expect(values.containsKey('errors'), isFalse);
    });

    test('plot elements get zeros and intersections keyed by id', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'model': {'expression': 'x^2'},
        'view': {
          'x': [-3, 3],
          'y': [-1, 9],
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'plot',
            'expression': '2*x',
            'domain': [-3, 3],
          },
        ],
      });
      final values = computeDerivedValues(scene);
      final elements = values['elements'] as Map;
      expect(elements.keys, ['p1']);
      final p1 = elements['p1'] as Map;
      final zeros = p1['zeros'] as List;
      expect(zeros, hasLength(1));
      expect(zeros.single, closeTo(0, 1e-9));
      final intersections = p1['intersections'] as List;
      expect(intersections, hasLength(2));
      final first = intersections[0] as Map;
      expect(first['x'], closeTo(0, 1e-6));
      expect(first['y'], closeTo(0, 1e-6));
      final second = intersections[1] as Map;
      expect(second['x'], closeTo(2, 1e-6));
      expect(second['y'], closeTo(4, 1e-6));
    });

    test('no view falls back to [-10, 10]', () {
      const scene = VisualScene(
        kind: VisualSceneKind.plot2d,
        model: VisualModel(expression: 'x^2-4'),
      );
      final values = computeDerivedValues(scene);
      final zeros = values['zeros'] as List;
      expect(zeros, hasLength(2));
      expect(zeros[0], closeTo(-2, 1e-9));
      expect(zeros[1], closeTo(2, 1e-9));
    });

    test('bad expressions are recorded under errors, never thrown', () {
      const scene = VisualScene(
        kind: VisualSceneKind.plot2d,
        model: VisualModel(expression: 'x + ('),
        elements: [
          PlotElement(
            id: 'p1',
            style: VisualStyle.primary,
            layer: 0,
            visible: true,
            expression: 'x^2',
            domain: (-2, 2),
          ),
        ],
      );
      final values = computeDerivedValues(scene);
      final errors = values['errors'] as List;
      expect(errors, isNotEmpty);
      expect(errors.first, contains('model'));
      // The valid plot element is still computed despite the bad model.
      final elements = values['elements'] as Map;
      final p1 = elements['p1'] as Map;
      expect((p1['zeros'] as List).single, closeTo(0, 1e-9));
    });

    test('scene without a model expression returns empty values', () {
      const scene = VisualScene(kind: VisualSceneKind.geometry);
      final values = computeDerivedValues(scene);
      expect(values['zeros'], isEmpty);
      expect(values['extrema'], isEmpty);
      expect(values.containsKey('errors'), isFalse);
    });
  });
}
