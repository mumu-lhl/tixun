import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';

/// P2 coverage for `visualRegionAtPoint`: boundary points, overlapping
/// polygons, `$param`-bound polygons and hidden polygons. All
/// expectations pin the current behaviour of the even-odd ray casting
/// in the painter.

VisualScene _squareScene({
  List<Map<String, dynamic>> extra = const [],
  Map<String, double>? parameters,
}) => VisualScene.fromJson({
  'v': 1,
  'kind': 'geometry',
  'title': '区域',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'sq',
      'type': 'polygon',
      'points': [
        [0, 0],
        [2, 0],
        [2, 2],
        [0, 2],
      ],
      'fill': true,
    },
    ...extra,
  ],
  'model': {'parameters': parameters ?? {}},
  'meta': {'alt': '区域'},
});

void main() {
  group('boundary points', () {
    test('an interior point resolves to the polygon', () {
      final scene = _squareScene();
      expect(visualRegionAtPoint(scene, const ui.Offset(1, 1), const {}), 'sq');
    });

    test('an exterior point resolves to null', () {
      final scene = _squareScene();
      expect(
        visualRegionAtPoint(scene, const ui.Offset(3, 3), const {}),
        isNull,
      );
    });

    test('a point on the left edge counts as inside', () {
      final scene = _squareScene();
      expect(visualRegionAtPoint(scene, const ui.Offset(0, 1), const {}), 'sq');
    });

    test('a point on the right edge does NOT count as inside', () {
      // The painter comment says "a point on an edge counts as
      // inside", but the strict `<` in the ray casting only honours
      // that for the left edge: a point on the right edge resolves
      // to null. Pinned as-is; the comment/behaviour mismatch is a
      // known P2, not fixed here.
      final scene = _squareScene();
      expect(
        visualRegionAtPoint(scene, const ui.Offset(2, 1), const {}),
        isNull,
      );
    });

    test('a point on the top edge does NOT count as inside', () {
      final scene = _squareScene();
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1, 2), const {}),
        isNull,
      );
    });

    test('a point exactly on a vertex counts as inside', () {
      final scene = _squareScene();
      expect(visualRegionAtPoint(scene, const ui.Offset(0, 0), const {}), 'sq');
    });
  });

  group('overlapping polygons', () {
    test('the later polygon in paint order wins', () {
      final scene = _squareScene(
        extra: [
          {
            'id': 'sq2',
            'type': 'polygon',
            'points': [
              [1, 1],
              [3, 1],
              [3, 3],
              [1, 3],
            ],
            'fill': true,
          },
        ],
      );
      // (1.5, 1.5) is inside both squares; sq2 paints later.
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1.5, 1.5), const {}),
        'sq2',
      );
      // (0.5, 0.5) is only inside sq.
      expect(
        visualRegionAtPoint(scene, const ui.Offset(0.5, 0.5), const {}),
        'sq',
      );
    });

    test('a higher layer wins over a later list position', () {
      // sq is earlier in the element list than sq2, but on a higher
      // layer: sq paints later and wins the overlap.
      final layered = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'title': '区域',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'sq',
            'type': 'polygon',
            'layer': 1,
            'points': [
              [0, 0],
              [2, 0],
              [2, 2],
              [0, 2],
            ],
            'fill': true,
          },
          {
            'id': 'sq2',
            'type': 'polygon',
            'layer': 0,
            'points': [
              [1, 1],
              [3, 1],
              [3, 3],
              [1, 3],
            ],
            'fill': true,
          },
        ],
        'meta': {'alt': '区域'},
      });
      expect(
        visualRegionAtPoint(layered, const ui.Offset(1.5, 1.5), const {}),
        'sq',
      );
    });
  });

  group('\$param polygons', () {
    VisualScene paramScene() => VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '参数区域',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'pq',
          'type': 'polygon',
          'points': [
            [
              {'\$param': 's'},
              0,
            ],
            [2, 0],
            [2, 2],
            [
              {'\$param': 's'},
              2,
            ],
          ],
          'fill': true,
        },
      ],
      'model': {
        'parameters': {'s': 0},
      },
      'meta': {'alt': '参数区域'},
    });

    test('the polygon resolves with the given parameter value', () {
      final scene = paramScene();
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1, 1), const {'s': 0}),
        'pq',
      );
    });

    test('moving the parameter moves the region', () {
      final scene = paramScene();
      // With s = 1.5 the quad spans x in [1.5, 2]: (1, 1) is outside.
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1, 1), const {'s': 1.5}),
        isNull,
      );
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1.75, 1), const {'s': 1.5}),
        'pq',
      );
    });

    test('a missing parameter skips the polygon', () {
      final scene = paramScene();
      expect(
        visualRegionAtPoint(scene, const ui.Offset(1, 1), const {}),
        isNull,
      );
    });
  });

  group('hidden polygons', () {
    test('a polygon hidden by a step cannot be tapped', () {
      final scene = _squareScene();
      expect(
        visualRegionAtPoint(
          scene,
          const ui.Offset(1, 1),
          const {},
          hiddenElementIds: {'sq'},
        ),
        isNull,
      );
    });
  });
}
