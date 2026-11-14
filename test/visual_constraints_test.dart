import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/visual/model/visual_constraints.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';
import 'package:tixun/features/visual/visual_card.dart';

/// A 3-4-5 right triangle: A(0,0), B(3,0), C(0,4), M the midpoint of BC,
/// and a circle centered at A with radius 4 (through C).
Map<String, dynamic> triangleJson({
  Map<String, dynamic>? meta,
  List<Map<String, dynamic>>? constraints,
}) => {
  'v': 1,
  'kind': 'geometry',
  'title': '直角三角形',
  'view': {
    'x': [-1, 5],
    'y': [-1, 5],
  },
  'elements': [
    {
      'id': 'A',
      'type': 'point',
      'at': [0, 0],
      'label': 'A',
    },
    {
      'id': 'B',
      'type': 'point',
      'at': [3, 0],
      'label': 'B',
    },
    {
      'id': 'C',
      'type': 'point',
      'at': [0, 4],
      'label': 'C',
    },
    {
      'id': 'M',
      'type': 'point',
      'at': [1.5, 2],
      'label': 'M',
    },
    {
      'id': 'AB',
      'type': 'line',
      'p1': [0, 0],
      'p2': [3, 0],
    },
    {
      'id': 'AC',
      'type': 'line',
      'p1': [0, 0],
      'p2': [0, 4],
    },
    {
      'id': 'BC',
      'type': 'line',
      'p1': [3, 0],
      'p2': [0, 4],
    },
    {
      // Horizontal, parallel to AB (for the parallel-satisfied case).
      'id': 'DE',
      'type': 'line',
      'p1': [0, 2],
      'p2': [3, 2],
    },
    {
      // Diagonal, disjoint from every other segment and parallel to none
      // of them (for the non-parallel disjoint intersect case).
      'id': 'FG',
      'type': 'line',
      'p1': [4, 1],
      'p2': [5, 2],
    },
    {
      'id': 'circ',
      'type': 'circle',
      'center': [0, 0],
      'r': 4,
    },
  ],
  'meta': ?meta,
  'constraints': ?constraints,
};

void main() {
  group('VisualConstraint model', () {
    test('every constraint type round-trips through JSON', () {
      const cases = [
        VisualConstraint(
          type: VisualConstraintType.distance,
          a: 'A',
          b: 'B',
          value: 3,
        ),
        VisualConstraint(type: VisualConstraintType.parallel, a: 'AB', b: 'BC'),
        VisualConstraint(
          type: VisualConstraintType.perpendicular,
          a: 'AB',
          b: 'AC',
        ),
        VisualConstraint(
          type: VisualConstraintType.onCircle,
          point: 'C',
          circle: 'circ',
        ),
        VisualConstraint(
          type: VisualConstraintType.angle,
          a: 'AB',
          b: 'AC',
          value: 90,
        ),
        VisualConstraint(
          type: VisualConstraintType.intersect,
          a: 'AB',
          b: 'AC',
        ),
        VisualConstraint(
          type: VisualConstraintType.midpoint,
          point: 'M',
          a: 'B',
          b: 'C',
        ),
      ];
      for (final c in cases) {
        final back = VisualConstraint.fromJson(c.toJson());
        expect(back.type, c.type);
        expect(back.a, c.a);
        expect(back.b, c.b);
        expect(back.point, c.point);
        expect(back.circle, c.circle);
        expect(back.value, c.value);
      }
      // `on_circle` is the DSL spelling of `onCircle`.
      expect(
        VisualConstraint.fromJson({
          'type': 'on_circle',
          'point': 'C',
          'circle': 'circ',
        }).type,
        VisualConstraintType.onCircle,
      );
      expect(
        const VisualConstraint(
          type: VisualConstraintType.onCircle,
          point: 'C',
          circle: 'circ',
        ).toJson()['type'],
        'on_circle',
      );
    });

    test('fromJson rejects bad shapes', () {
      expect(
        () => VisualConstraint.fromJson({'type': 'tangent'}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () =>
            VisualConstraint.fromJson({'type': 'distance', 'a': 'A', 'b': 'B'}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualConstraint.fromJson({
          'type': 'angle',
          'a': 'AB',
          'b': 'AC',
          'value': 200,
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualConstraint.fromJson({
          'type': 'distance',
          'a': 'A',
          'b': 'B',
          'value': -1,
        }),
        throwsA(isA<AppFormatException>()),
      );
    });
  });

  group('validateVisualScene: constraints', () {
    test('a correct 3-4-5 construction satisfies every constraint', () {
      final v = validateVisualScene(
        triangleJson(
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 3},
            {'type': 'distance', 'a': 'A', 'b': 'C', 'value': 4},
            {'type': 'distance', 'a': 'B', 'b': 'C', 'value': 5},
            {'type': 'perpendicular', 'a': 'AB', 'b': 'AC'},
            {'type': 'parallel', 'a': 'AB', 'b': 'DE'},
            {'type': 'angle', 'a': 'AB', 'b': 'AC', 'value': 90},
            {'type': 'intersect', 'a': 'AB', 'b': 'AC'},
            {'type': 'midpoint', 'point': 'M', 'a': 'B', 'b': 'C'},
            {'type': 'on_circle', 'point': 'C', 'circle': 'circ'},
          ],
        ),
      );
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      expect(v.verificationStatus, 'verified');
    });

    test('each violated constraint fails with constraint_violated', () {
      final violations = <Map<String, dynamic>>[
        {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 4},
        {'type': 'parallel', 'a': 'AB', 'b': 'AC'},
        {'type': 'perpendicular', 'a': 'AB', 'b': 'BC'},
        {'type': 'angle', 'a': 'AB', 'b': 'AC', 'value': 45},
        // AB and FG are not parallel, but their lines meet outside both
        // segments; AB and DE are parallel and disjoint.
        {'type': 'intersect', 'a': 'AB', 'b': 'FG'},
        {'type': 'intersect', 'a': 'AB', 'b': 'DE'},
        {'type': 'midpoint', 'point': 'A', 'a': 'B', 'b': 'C'},
        {'type': 'on_circle', 'point': 'B', 'circle': 'circ'},
      ];
      for (final c in violations) {
        final v = validateVisualScene(triangleJson(constraints: [c]));
        expect(v.ok, isFalse, reason: c.toString());
        expect(
          v.errors.any((e) => e.code == 'constraint_violated'),
          isTrue,
          reason: c.toString(),
        );
      }
    });

    test(
      'intersect: disjoint segments do not intersect, overlapping ones do',
      () {
        Map<String, dynamic> segScene(
          List<double> p1,
          List<double> p2,
          List<double> q1,
          List<double> q2,
        ) => {
          'v': 1,
          'kind': 'geometry',
          'title': 'segments',
          'elements': [
            {'id': 'L1', 'type': 'line', 'p1': p1, 'p2': p2},
            {'id': 'L2', 'type': 'line', 'p1': q1, 'p2': q2},
          ],
          'constraints': [
            {'type': 'intersect', 'a': 'L1', 'b': 'L2'},
          ],
        };
        // Not parallel, but their lines meet outside both segments.
        expect(
          validateVisualScene(segScene([0, 0], [1, 0], [10, 10], [10, 11]))
              .errors
              .any((e) => e.code == 'constraint_violated'),
          isTrue,
        );
        // Collinear and overlapping: they intersect.
        expect(
          validateVisualScene(segScene([0, 0], [2, 0], [1, 0], [3, 0])).ok,
          isTrue,
        );
        // Touching at an endpoint: they intersect.
        expect(
          validateVisualScene(segScene([0, 0], [2, 0], [2, 0], [4, 0])).ok,
          isTrue,
        );
        // Crossing in the middle: they intersect.
        expect(
          validateVisualScene(segScene([0, 0], [2, 2], [0, 2], [2, 0])).ok,
          isTrue,
        );
      },
    );

    test('parallel, perpendicular and angle share one tolerance', () {
      VisualValidation check(
        List<double> a1,
        List<double> a2,
        List<double> b1,
        List<double> b2,
        List<Map<String, dynamic>> constraints,
      ) => validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'title': 'angle tolerance',
        'elements': [
          {'id': 'L1', 'type': 'line', 'p1': a1, 'p2': a2},
          {'id': 'L2', 'type': 'line', 'p1': b1, 'p2': b2},
        ],
        'constraints': constraints,
      });
      // 5e-5 degrees off horizontal: inside the shared 1e-4-degree
      // tolerance, so angle and parallel agree (both pass).
      final d5 = 5e-5 * math.pi / 180;
      var v = check([0, 0], [1, 0], [0, 0], [math.cos(d5), math.sin(d5)], [
        {'type': 'angle', 'a': 'L1', 'b': 'L2', 'value': 0},
        {'type': 'parallel', 'a': 'L1', 'b': 'L2'},
      ]);
      expect(v.ok, isTrue);
      // 2e-4 degrees off: outside the tolerance, both fail together.
      final d20 = 2e-4 * math.pi / 180;
      v = check([0, 0], [1, 0], [0, 0], [math.cos(d20), math.sin(d20)], [
        {'type': 'angle', 'a': 'L1', 'b': 'L2', 'value': 0},
        {'type': 'parallel', 'a': 'L1', 'b': 'L2'},
      ]);
      expect(
        v.errors.where((e) => e.code == 'constraint_violated'),
        hasLength(2),
      );
      // 5e-5 degrees off a right angle: perpendicular and angle agree.
      v = check([0, 0], [1, 0], [0, 0], [-math.sin(d5), math.cos(d5)], [
        {'type': 'angle', 'a': 'L1', 'b': 'L2', 'value': 90},
        {'type': 'perpendicular', 'a': 'L1', 'b': 'L2'},
      ]);
      expect(v.ok, isTrue);
      // Short segments: coordinates rounded to ~1e-6 tilt a 1e-3 segment
      // by ~0.029 degrees, which the length-scaled tolerance accepts.
      v = check([0, 0], [0.001, 0], [0, 0], [0.001, 0.0000005], [
        {'type': 'angle', 'a': 'L1', 'b': 'L2', 'value': 0},
        {'type': 'parallel', 'a': 'L1', 'b': 'L2'},
      ]);
      expect(v.ok, isTrue);
      // Same short segments tilted 0.1 degrees: beyond the scaled
      // tolerance (~0.057 degrees), both fail together.
      final y01 = 0.001 * math.tan(0.1 * math.pi / 180);
      v = check([0, 0], [0.001, 0], [0, 0], [0.001, y01], [
        {'type': 'angle', 'a': 'L1', 'b': 'L2', 'value': 0},
        {'type': 'parallel', 'a': 'L1', 'b': 'L2'},
      ]);
      expect(
        v.errors.where((e) => e.code == 'constraint_violated'),
        hasLength(2),
      );
    });

    test('malformed constraint fields are errors, not throws', () {
      for (final Map<String, dynamic> c in <Map<String, dynamic>>[
        {'type': 'distance', 'a': 123, 'b': 'B', 'value': 5},
        {'type': 'distance', 'a': 'A', 'b': 'B', 'value': '5'},
        {'type': 'distance', 'a': '', 'b': 'B', 'value': 5},
      ]) {
        final v = validateVisualScene(triangleJson(constraints: [c]));
        expect(v.ok, isFalse, reason: c.toString());
        expect(
          v.errors.any((e) => e.code == 'invalid_type'),
          isTrue,
          reason: c.toString(),
        );
      }
    });

    test('unknown ids and wrong element kinds are errors', () {
      expect(
        validateVisualScene(
          triangleJson(
            constraints: [
              {'type': 'distance', 'a': 'A', 'b': 'ZZ', 'value': 1},
            ],
          ),
        ).errors.any((e) => e.code == 'unknown_element'),
        isTrue,
      );
      expect(
        validateVisualScene(
          triangleJson(
            constraints: [
              {'type': 'distance', 'a': 'A', 'b': 'AB', 'value': 1},
            ],
          ),
        ).errors.any((e) => e.code == 'invalid_value'),
        isTrue,
      );
    });

    test('a bound coordinate makes the constraint unverifiable, not wrong', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'model': {
          'parameters': {'a': 1.0},
        },
        'controls': [
          {
            'id': 'a',
            'kind': 'slider',
            'label': 'a',
            'min': 0,
            'max': 3,
            'step': 0.1,
            'value': 1,
          },
        ],
        'elements': [
          {
            'id': 'P',
            'type': 'point',
            'at': [
              {r'$param': 'a'},
              0,
            ],
          },
          {
            'id': 'Q',
            'type': 'point',
            'at': [3, 0],
          },
        ],
        'constraints': [
          {'type': 'distance', 'a': 'P', 'b': 'Q', 'value': 2},
        ],
      });
      expect(v.ok, isTrue);
      expect(
        v.warnings.any((w) => w.code == 'constraint_unverifiable'),
        isTrue,
      );
      // An unverifiable constraint is not verified: the scene is a
      // schematic as far as checking is concerned.
      expect(v.verificationStatus, 'schematic');
    });

    test('a schematic scene downgrades violations to warnings', () {
      final v = validateVisualScene(
        triangleJson(
          meta: {'schematic': true, 'alt': '直角三角形示意图'},
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 4},
          ],
        ),
      );
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      expect(v.warnings.any((w) => w.code == 'schematic_constraint'), isTrue);
      expect(v.verificationStatus, 'schematic');
    });

    test('constraints survive a scene round-trip', () {
      final scene = VisualScene.fromJson(
        triangleJson(
          constraints: [
            {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 3},
            {'type': 'perpendicular', 'a': 'AB', 'b': 'AC'},
          ],
        ),
      );
      expect(scene.constraints.length, 2);
      expect(scene.constraints.first.type, VisualConstraintType.distance);
      expect(scene.constraints.first.value, 3);
      expect(VisualScene.fromJson(scene.toJson()).constraints.length, 2);
    });
  });

  testWidgets('schematic scenes show the not-to-scale note on the card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualCard(
            scene: VisualScene.fromJson(
              triangleJson(
                meta: {'schematic': true, 'alt': '直角三角形示意图'},
                constraints: [
                  {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 4},
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('示意图，不按比例'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualCard(
            scene: VisualScene.fromJson(
              triangleJson(
                constraints: [
                  {'type': 'distance', 'a': 'A', 'b': 'B', 'value': 3},
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('示意图，不按比例'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
