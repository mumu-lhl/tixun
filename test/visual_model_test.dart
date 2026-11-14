import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';

/// A scene exercising every element type, all control kinds, timeline,
/// annotations and meta.
Map<String, dynamic> fullSceneJson() => {
  'v': 1,
  'kind': 'plot2d',
  'title': '二次函数',
  'model': {
    'expression': 'x^2-4',
    'parameters': {'a': 1},
  },
  'view': {
    'x': [-3, 3],
    'y': [-5, 6],
  },
  'elements': [
    {
      'id': 'e1',
      'type': 'point',
      'at': [0, -4],
      'label': '顶点',
    },
    {
      'id': 'e2',
      'type': 'line',
      'p1': [-3, 5],
      'p2': [3, 5],
      'dashed': true,
    },
    {
      'id': 'e3',
      'type': 'polyline',
      'points': [
        [0, 0],
        [1, 1],
        [2, 0],
      ],
    },
    {
      'id': 'e4',
      'type': 'polygon',
      'points': [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      'fill': true,
    },
    {
      'id': 'e5',
      'type': 'circle',
      'center': [0, 0],
      'r': 2,
    },
    {
      'id': 'e6',
      'type': 'arc',
      'center': [0, 0],
      'r': 1,
      'startDeg': 0,
      'sweepDeg': 90,
    },
    {
      'id': 'e7',
      'type': 'arrow',
      'from': [0, 0],
      'to': [1, 2],
    },
    {
      'id': 'e8',
      'type': 'text',
      'at': [1, 1],
      'text': '交点',
    },
    {
      'id': 'e9',
      'type': 'math_label',
      'at': [2, 0],
      'tex': r'x^2-4',
    },
    {
      'id': 'e10',
      'type': 'group',
      'children': [
        {
          'id': 'e11',
          'type': 'point',
          'at': [1, 1],
        },
      ],
    },
    {
      'id': 'e12',
      'type': 'plot',
      'expression': 'a*x^2-4',
      'domain': [-3, 3],
      'samples': 512,
    },
  ],
  'controls': [
    {
      'id': 'a',
      'kind': 'slider',
      'label': 'a',
      'min': -3,
      'max': 3,
      'step': 0.1,
      'value': 1,
    },
    {'id': 'showAux', 'kind': 'toggle', 'label': '显示辅助线', 'value': true},
    {
      'id': 'mode',
      'kind': 'choice',
      'label': '情形',
      'options': ['A', 'B'],
      'value': 'A',
    },
  ],
  'timeline': {
    'durationMs': 4000,
    'tracks': [
      {
        'id': 't1',
        'target': 'a',
        'from': 1,
        'to': 3,
        'startMs': 0,
        'endMs': 4000,
      },
    ],
    'steps': [
      {
        'atMs': 0,
        'show': ['e1'],
        'hide': [],
        'note': '画坐标轴',
      },
    ],
  },
  'annotations': [
    {
      'at': [0, 0],
      'text': '顶点',
    },
  ],
  'meta': {'alt': '抛物线 y=x^2-4 的图像'},
};

void main() {
  group('VisualScene.fromJson / toJson', () {
    test('round-trip preserves the scene', () {
      final scene = VisualScene.fromJson(fullSceneJson());
      expect(scene.kind, VisualSceneKind.plot2d);
      expect(scene.title, '二次函数');
      expect(scene.model?.expression, 'x^2-4');
      expect(scene.model?.parameters, {'a': 1.0});
      expect(scene.view?.x?.min, -3);
      expect(scene.view?.y?.max, 6);
      expect(scene.elements, hasLength(11));
      expect(scene.allElementIds, hasLength(12));
      expect(scene.controls, hasLength(3));
      expect(scene.controls.first, isA<SliderControl>());
      expect(scene.controls[1], isA<ToggleControl>());
      expect(scene.controls[2], isA<ChoiceControl>());
      expect(scene.timeline?.durationMs, 4000);
      expect(scene.timeline?.tracks, hasLength(1));
      expect(scene.timeline?.steps, hasLength(1));
      expect(scene.annotations, hasLength(1));
      expect(scene.meta?.alt, '抛物线 y=x^2-4 的图像');

      // Serializing and parsing again yields the same JSON.
      final again = VisualScene.fromJson(scene.toJson());
      expect(again.toJson(), scene.toJson());
    });

    test('minimal scene round-trips', () {
      final scene = VisualScene.fromJson({'v': 1, 'kind': 'geometry'});
      expect(scene.kind, VisualSceneKind.geometry);
      expect(scene.elements, isEmpty);
      expect(scene.controls, isEmpty);
      expect(scene.toJson(), {'v': 1, 'kind': 'geometry'});
      expect(
        VisualScene.fromJson(scene.toJson()).kind,
        VisualSceneKind.geometry,
      );
    });

    test('all element types parse with expected fields', () {
      final scene = VisualScene.fromJson(fullSceneJson());
      final byId = {for (final e in scene.elements) e.id: e};
      expect((byId['e1'] as PointElement).label, '顶点');
      expect((byId['e2'] as LineElement).dashed, isTrue);
      expect((byId['e3'] as PolylineElement).points, hasLength(3));
      expect((byId['e4'] as PolygonElement).fill, isTrue);
      expect((byId['e5'] as CircleElement).r, 2);
      expect((byId['e6'] as ArcElement).sweepDeg, 90);
      expect((byId['e7'] as ArrowElement).to.literal, (1.0, 2.0));
      expect((byId['e8'] as TextElement).text, '交点');
      expect((byId['e9'] as MathLabelElement).tex, r'x^2-4');
      expect((byId['e10'] as GroupElement).children, hasLength(1));
      expect((byId['e12'] as PlotElement).samples, 512);
      expect((byId['e12'] as PlotElement).domain, (-3.0, 3.0));
    });

    test(r'$param coordinate bindings parse and round-trip', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'model': {
          'parameters': {'a': 2},
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'point',
            'at': [
              {r'$param': 'a'},
              3,
            ],
          },
        ],
      });
      final point = (scene.elements.single as PointElement).at;
      expect(point.x.isParam, isTrue);
      expect(point.x.param, 'a');
      expect(point.y.literalValue, 3);
      expect(
        VisualScene.fromJson(scene.toJson()).elements.single,
        isA<PointElement>(),
      );
      final reparsed =
          (VisualScene.fromJson(scene.toJson()).elements.single as PointElement)
              .at;
      expect(reparsed.x.param, 'a');
    });

    test('element defaults: primary style, layer 0, visible', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          {
            'id': 'p',
            'type': 'point',
            'at': [0, 0],
          },
        ],
      });
      final element = scene.elements.single;
      expect(element.style, VisualStyle.primary);
      expect(element.layer, 0);
      expect(element.visible, isTrue);
      expect(element.visibleWhen, isNull);
    });

    test('visibleWhen gate parses', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'controls': [
          {'id': 'showAux', 'kind': 'toggle', 'label': '辅助线', 'value': true},
        ],
        'elements': [
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
            'p2': [1, 1],
            'visibleWhen': {'control': 'showAux', 'equals': true},
          },
        ],
      });
      final element = scene.elements.single;
      expect(element.visibleWhen?.control, 'showAux');
      expect(element.visibleWhen?.equals, isTrue);
    });
  });

  group('VisualScene.fromJson rejects malformed input', () {
    test('unknown top-level field', () {
      expect(
        () =>
            VisualScene.fromJson({'v': 1, 'kind': 'plot2d', 'surprise': true}),
        throwsA(isA<AppFormatException>()),
      );
    });

    test('unknown fields at every nested level', () {
      final cases = <Map<String, dynamic>>[
        {
          'v': 1,
          'kind': 'plot2d',
          'model': {'expression': 'x', 'nope': 1},
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'view': {
            'x': [-1, 1],
            'nope': 1,
          },
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'meta': {'alt': 'x', 'nope': 1},
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'annotations': [
            {
              'at': [0, 0],
              'text': 't',
              'nope': 1,
            },
          ],
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'elements': [
            {
              'id': 'p',
              'type': 'point',
              'at': [0, 0],
              'nope': 1,
            },
          ],
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'elements': [
            {
              'id': 'l',
              'type': 'line',
              'p1': [0, 0],
              'p2': [1, 1],
              'visibleWhen': {'control': 'c', 'equals': true, 'nope': 1},
            },
          ],
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'controls': [
            {
              'id': 'a',
              'kind': 'toggle',
              'label': 'x',
              'value': true,
              'nope': 1,
            },
          ],
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'timeline': {'durationMs': 100, 'nope': 1},
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'timeline': {
            'durationMs': 100,
            'tracks': [
              {
                'id': 't',
                'target': 'a',
                'from': 0,
                'to': 1,
                'startMs': 0,
                'endMs': 10,
                'nope': 1,
              },
            ],
          },
        },
        {
          'v': 1,
          'kind': 'plot2d',
          'timeline': {
            'durationMs': 100,
            'steps': [
              {'atMs': 0, 'nope': 1},
            ],
          },
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'p',
              'type': 'point',
              'at': [
                {r'$param': 'a', 'nope': 1},
                0,
              ],
            },
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: 'expected $json to fail',
        );
      }
    });

    test('missing required fields', () {
      expect(
        () => VisualScene.fromJson({}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({'kind': 'plot2d'}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({'v': 1}),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'type': 'point',
              'at': [0, 0],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test('wrong JSON types throw AppFormatException, not TypeError', () {
      final cases = <Map<String, dynamic>>[
        {'v': 1, 'kind': 123},
        {
          'v': 1,
          'kind': 'plot2d',
          'elements': {'id': 'x'},
        },
        {'v': 1, 'kind': 'plot2d', 'model': 'x'},
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {'id': 'p', 'type': 'point', 'at': 'origin'},
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'p',
              'type': 'point',
              'at': [0, 0],
              'dashed': 'yes',
            },
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'c',
              'type': 'circle',
              'center': [0, 0],
              'r': 'big',
            },
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: 'expected $json to fail with AppFormatException',
        );
      }
    });

    test('duplicate element ids (including inside groups)', () {
      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'p',
              'type': 'point',
              'at': [0, 0],
            },
            {
              'id': 'p',
              'type': 'point',
              'at': [1, 1],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'g',
              'type': 'group',
              'children': [
                {
                  'id': 'p',
                  'type': 'point',
                  'at': [0, 0],
                },
                {
                  'id': 'p',
                  'type': 'point',
                  'at': [1, 1],
                },
              ],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test('bad ranges and counts', () {
      final cases = <Map<String, dynamic>>[
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'c',
              'type': 'circle',
              'center': [0, 0],
              'r': 0,
            },
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'a',
              'type': 'arc',
              'center': [0, 0],
              'r': 1,
              'startDeg': 0,
              'sweepDeg': 0,
            },
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'l',
              'type': 'polyline',
              'points': [
                [0, 0],
              ],
            },
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'p',
              'type': 'polygon',
              'points': [
                [0, 0],
                [1, 1],
              ],
            },
          ],
        },
        {
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {'id': 'g', 'type': 'group', 'children': []},
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => VisualScene.fromJson(json),
          throwsA(isA<AppFormatException>()),
          reason: 'expected $json to fail',
        );
      }
    });

    test('group nesting deeper than 4 is rejected; depth 4 is allowed', () {
      Map<String, dynamic> nestedGroup(int depth) {
        if (depth == 0) {
          return {
            'id': 'leaf',
            'type': 'point',
            'at': [0, 0],
          };
        }
        return {
          'id': 'g$depth',
          'type': 'group',
          'children': [nestedGroup(depth - 1)],
        };
      }

      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [nestedGroup(4)],
        }),
        returnsNormally,
      );
      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [nestedGroup(5)],
        }),
        throwsA(isA<AppFormatException>()),
      );
    });

    test('unknown element type and kind', () {
      expect(
        () => VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'elements': [
            {
              'id': 'x',
              'type': 'star',
              'at': [0, 0],
            },
          ],
        }),
        throwsA(isA<AppFormatException>()),
      );
      expect(
        () => VisualScene.fromJson({'v': 1, 'kind': 'hologram'}),
        throwsA(isA<AppFormatException>()),
      );
    });
  });
}
