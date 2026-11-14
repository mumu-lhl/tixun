import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

/// P2 coverage for geometric constraints: degenerate (zero-length)
/// segments and tolerance boundaries. All expectations pin the current
/// validator behaviour.

/// A geometry scene with the given points, lines and constraints.
Map<String, dynamic> _scene({
  required List<Map<String, dynamic>> elements,
  required List<Map<String, dynamic>> constraints,
}) => {
  'v': 1,
  'kind': 'geometry',
  'title': '约束边界',
  'view': {
    'x': [-10, 10],
    'y': [-10, 10],
  },
  'elements': elements,
  'constraints': constraints,
  'meta': {'alt': '约束边界图'},
};

Map<String, dynamic> _point(String id, double x, double y) => {
  'id': id,
  'type': 'point',
  'at': [x, y],
};

Map<String, dynamic> _line(
  String id,
  double x1,
  double y1,
  double x2,
  double y2,
) => {
  'id': id,
  'type': 'line',
  'p1': [x1, y1],
  'p2': [x2, y2],
};

Map<String, dynamic> _circle(String id, double x, double y, double r) => {
  'id': id,
  'type': 'circle',
  'center': [x, y],
  'r': r,
};

void main() {
  group('degenerate segments', () {
    test('parallel with a zero-length segment is an invalid_value error', () {
      final v = validateVisualScene(
        _scene(
          elements: [_line('AB', 0, 0, 0, 0), _line('CD', 0, 1, 3, 1)],
          constraints: [
            {'type': 'parallel', 'a': 'AB', 'b': 'CD'},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_value'));
      expect(v.errors.map((e) => e.message), contains('约束引用的线段退化为点，无法比较方向。'));
    });

    test('angle with a zero-length segment is an invalid_value error', () {
      final v = validateVisualScene(
        _scene(
          elements: [_line('AB', 1, 1, 1, 1), _line('CD', 0, 0, 3, 4)],
          constraints: [
            {'type': 'angle', 'a': 'AB', 'b': 'CD', 'value': 45},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_value'));
    });

    test(
      'perpendicular with a zero-length segment is an invalid_value error',
      () {
        final v = validateVisualScene(
          _scene(
            elements: [_line('AB', 0, 0, 4, 0), _line('CD', 2, 2, 2, 2)],
            constraints: [
              {'type': 'perpendicular', 'a': 'AB', 'b': 'CD'},
            ],
          ),
        );
        expect(v.ok, isFalse);
        expect(v.errors.map((e) => e.code), contains('invalid_value'));
      },
    );

    test('intersect with a zero-length segment is an invalid_value error', () {
      final v = validateVisualScene(
        _scene(
          elements: [_line('AB', 0, 0, 0, 0), _line('CD', -1, -1, 1, 1)],
          constraints: [
            {'type': 'intersect', 'a': 'AB', 'b': 'CD'},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_value'));
    });

    test('a degenerate segment with no constraint is fine', () {
      // A zero-length line on its own is not an error: only the
      // direction-comparing constraints reject it.
      final v = validateVisualScene(
        _scene(elements: [_line('AB', 0, 0, 0, 0)], constraints: const []),
      );
      expect(v.ok, isTrue);
    });
  });

  group('tolerance boundaries', () {
    test('distance: exactly at the tolerance edge passes', () {
      // Points (0,0)-(3,4): actual distance 5. Tolerance is
      // 1e-6 * |value| = 5e-6, so value 5.000005 passes.
      final v = validateVisualScene(
        _scene(
          elements: [_point('A', 0, 0), _point('B', 3, 4)],
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 5.000005},
          ],
        ),
      );
      expect(v.ok, isTrue);
    });

    test('distance: just past the tolerance edge violates', () {
      final v = validateVisualScene(
        _scene(
          elements: [_point('A', 0, 0), _point('B', 3, 4)],
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 5.000006},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('distance: tiny values no longer pass on an absolute floor', () {
      // value 1e-6, actual 2e-6: the error is 100% in relative terms.
      // The tolerance is purely relative now (1e-6 * |value| = 1e-12),
      // so this violates. The old absolute 1e-6 floor used to let any
      // small-scale geometry pass unexamined.
      final v = validateVisualScene(
        _scene(
          elements: [_point('A', 0, 0), _point('B', 0.000002, 0)],
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 0.000001},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('midpoint: exactly 1e-6 off in one component passes', () {
      // Coordinate scale here is 2 (point B), so the tolerance is
      // 1e-6 * 2 = 2e-6 and a 1e-6 deviation passes.
      final v = validateVisualScene(
        _scene(
          elements: [
            _point('A', 0, 0),
            _point('B', 2, 0),
            _point('M', 1, 0.000001),
          ],
          constraints: [
            {'type': 'midpoint', 'point': 'M', 'a': 'A', 'b': 'B'},
          ],
        ),
      );
      expect(v.ok, isTrue);
    });

    test('midpoint: 3e-6 off in one component violates', () {
      // Same scale (tolerance 2e-6): 3e-6 off is past it.
      final v = validateVisualScene(
        _scene(
          elements: [
            _point('A', 0, 0),
            _point('B', 2, 0),
            _point('M', 1, 0.000003),
          ],
          constraints: [
            {'type': 'midpoint', 'point': 'M', 'a': 'A', 'b': 'B'},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('midpoint: tiny-scale figures are checked at their own scale', () {
      // A 1e-9-scale figure: the tolerance is 1e-6 * 1e-9 = 1e-15, so
      // a 5e-10 deviation violates. The old absolute 1e-6 tolerance
      // would have swallowed the whole figure.
      final v = validateVisualScene(
        _scene(
          elements: [
            _point('A', 0, 0),
            _point('B', 0.000000001, 0),
            _point('M', 0.0000000005, 0.0000000005),
          ],
          constraints: [
            {'type': 'midpoint', 'point': 'M', 'a': 'A', 'b': 'B'},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('on_circle: exactly at the tolerance edge passes', () {
      // r = 2, tolerance 1e-6 * r = 2e-6.
      final v = validateVisualScene(
        _scene(
          elements: [_circle('C', 0, 0, 2), _point('P', 2.000002, 0)],
          constraints: [
            {'type': 'on_circle', 'point': 'P', 'circle': 'C'},
          ],
        ),
      );
      expect(v.ok, isTrue);
    });

    test('on_circle: past the tolerance edge violates', () {
      final v = validateVisualScene(
        _scene(
          elements: [_circle('C', 0, 0, 2), _point('P', 2.000003, 0)],
          constraints: [
            {'type': 'on_circle', 'point': 'P', 'circle': 'C'},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('parallel: short segments get the length-scaled tolerance', () {
      // Both segments are 0.01 long, so the shared angle tolerance is
      // 1e-6 / 0.01 rad ≈ 0.00573° (above the 1e-4° floor). A 0.003°
      // deviation passes, a 0.01° deviation fails.
      Map<String, dynamic> sceneWith(double deviationDeg) {
        final dy = 0.01 * math.tan(deviationDeg * math.pi / 180);
        return _scene(
          elements: [
            _line('AB', 0, 0, 0.01, 0),
            _line('CD', 0, 1, 0.01, 1 + dy),
          ],
          constraints: [
            {'type': 'parallel', 'a': 'AB', 'b': 'CD'},
          ],
        );
      }

      expect(validateVisualScene(sceneWith(0.003)).ok, isTrue);
      final v = validateVisualScene(sceneWith(0.01));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('constraint_violated'));
    });

    test('angle and parallel agree at the shared tolerance boundary', () {
      // Same 0.01-long segments, deviation 0.003°: the angle check
      // with value 0 and the parallel check must give the same
      // verdict (both pass).
      final dy = 0.01 * math.tan(0.003 * math.pi / 180);
      final elements = [
        _line('AB', 0, 0, 0.01, 0),
        _line('CD', 0, 1, 0.01, 1 + dy),
      ];
      final parallel = validateVisualScene(
        _scene(
          elements: elements,
          constraints: [
            {'type': 'parallel', 'a': 'AB', 'b': 'CD'},
          ],
        ),
      );
      final angle = validateVisualScene(
        _scene(
          elements: elements,
          constraints: [
            {'type': 'angle', 'a': 'AB', 'b': 'CD', 'value': 0},
          ],
        ),
      );
      expect(parallel.ok, isTrue);
      expect(angle.ok, isTrue);
    });
  });
}
