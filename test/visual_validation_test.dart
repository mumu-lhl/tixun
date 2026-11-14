import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

Map<String, dynamic> validPlotScene() => {
  'v': 1,
  'kind': 'plot2d',
  'title': '二次函数',
  'model': {'expression': 'x^2-4'},
  'view': {
    'x': [-3, 3],
    'y': [-5, 6],
  },
  'elements': [
    {
      'id': 'p',
      'type': 'point',
      'at': [0, -4],
    },
  ],
};

bool hasError(VisualValidation v, String code) =>
    v.errors.any((e) => e.code == code);

bool hasWarning(VisualValidation v, String code) =>
    v.warnings.any((w) => w.code == code);

void main() {
  group('validateVisualScene: valid scenes', () {
    test('valid plot2d scene is ok and verified', () {
      final v = validateVisualScene(validPlotScene());
      expect(v.ok, isTrue);
      expect(v.errors, isEmpty);
      expect(v.verificationStatus, 'verified');
      expect(v.computed, isEmpty);
    });

    test('parameterized expression is ok when the parameter exists', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'title': 't',
        'model': {
          'expression': 'a*x^2',
          'parameters': {'a': 2},
        },
      });
      expect(v.ok, isTrue);
      expect(v.verificationStatus, 'verified');
    });

    test('schematic meta yields schematic status', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'physics',
        'title': '斜面受力',
        'meta': {'alt': '斜面示意图', 'schematic': true},
        'elements': [
          {
            'id': 'b',
            'type': 'polygon',
            'points': [
              [0, 0],
              [4, 0],
              [0, 2],
            ],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, 'schematic_content'), isTrue);
      expect(v.verificationStatus, 'schematic');
    });

    test('missing title and alt is a warning, not an error', () {
      final v = validateVisualScene({'v': 1, 'kind': 'geometry'});
      expect(v.ok, isTrue);
      expect(hasWarning(v, 'missing_accessibility_text'), isTrue);
      expect(v.verificationStatus, 'verified');
    });
  });

  group('validateVisualScene: structural errors', () {
    test('empty scene reports missing v and kind', () {
      final v = validateVisualScene({});
      expect(v.ok, isFalse);
      expect(v.verificationStatus, 'unverified');
      expect(hasError(v, 'missing_field'), isTrue);
    });

    test('unknown top-level field', () {
      final v = validateVisualScene({'v': 1, 'kind': 'plot2d', 'surprise': 1});
      expect(hasError(v, 'unknown_field'), isTrue);
      expect(
        v.errors.firstWhere((e) => e.code == 'unknown_field').path,
        'surprise',
      );
    });

    test('unsupported version', () {
      expect(
        hasError(
          validateVisualScene({'v': 2, 'kind': 'plot2d'}),
          'unsupported_version',
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene({'v': '1', 'kind': 'plot2d'}),
          'unsupported_version',
        ),
        isTrue,
      );
    });

    test('unknown kind and element type', () {
      expect(
        hasError(
          validateVisualScene({'v': 1, 'kind': 'hologram'}),
          'unknown_kind',
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene({
            'v': 1,
            'kind': 'geometry',
            'elements': [
              {'id': 'x', 'type': 'star'},
            ],
          }),
          'unknown_element_type',
        ),
        isTrue,
      );
    });

    test('duplicate element and control ids', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          {
            'id': 'p',
            'type': 'point',
            'at': [0, 0],
          },
          {
            'id': 'g',
            'type': 'group',
            'children': [
              {
                'id': 'p',
                'type': 'point',
                'at': [1, 1],
              },
            ],
          },
        ],
        'controls': [
          {'id': 't', 'kind': 'toggle', 'label': 'x', 'value': true},
          {'id': 't', 'kind': 'toggle', 'label': 'y', 'value': false},
        ],
      });
      expect(v.errors.where((e) => e.code == 'duplicate_id'), hasLength(2));
    });

    test('bad view ranges', () {
      final cases = <(Map<String, dynamic>, String)>[
        (
          {
            'x': [3, -3],
          },
          'invalid_range',
        ),
        (
          {
            'x': [0, 0],
          },
          'invalid_range',
        ),
        (
          {
            'x': [-1e10, 1e10],
          },
          'invalid_range',
        ),
        (
          {
            'x': [0],
          },
          'invalid_type',
        ),
        (
          {
            'y': ['a', 1],
          },
          'invalid_type',
        ),
      ];
      for (final (view, code) in cases) {
        expect(
          hasError(
            validateVisualScene({'v': 1, 'kind': 'plot2d', 'view': view}),
            code,
          ),
          isTrue,
          reason: 'expected $view to fail with $code',
        );
      }
    });

    test('bad element ranges', () {
      final cases = <Map<String, dynamic>>[
        {
          'id': 'c',
          'type': 'circle',
          'center': [0, 0],
          'r': 0,
        },
        {
          'id': 'c',
          'type': 'circle',
          'center': [0, 0],
          'r': -1,
        },
        {
          'id': 'a',
          'type': 'arc',
          'center': [0, 0],
          'r': 1,
          'startDeg': 0,
          'sweepDeg': 0,
        },
        {
          'id': 'l',
          'type': 'polyline',
          'points': [
            [0, 0],
          ],
        },
        {
          'id': 'p',
          'type': 'polygon',
          'points': [
            [0, 0],
            [1, 1],
          ],
        },
        {'id': 'g', 'type': 'group', 'children': []},
        {
          'id': 't',
          'type': 'text',
          'at': [0, 0],
          'text': '',
        },
        {
          'id': 'm',
          'type': 'math_label',
          'at': [0, 0],
          'tex': 'x' * 501,
        },
      ];
      for (final element in cases) {
        final v = validateVisualScene({
          'v': 1,
          'kind': 'geometry',
          'elements': [element],
        });
        expect(v.ok, isFalse, reason: 'expected $element to fail');
      }
    });

    test('missing required fields', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          {
            'type': 'point',
            'at': [0, 0],
          },
          {
            'id': 'c',
            'type': 'circle',
            'center': [0, 0],
          },
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
          },
        ],
      });
      expect(v.errors.where((e) => e.code == 'missing_field').length, 3);
    });
  });

  group('validateVisualScene: expressions and references', () {
    test('expression parse failure', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {'expression': 'x^^2'},
      });
      expect(hasError(v, 'expression_error'), isTrue);
    });

    test('unknown variable in model and plot expressions', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {'expression': 'y+1'},
        'elements': [
          {'id': 'p', 'type': 'plot', 'expression': 'z*x'},
        ],
      });
      expect(v.errors.where((e) => e.code == 'unknown_variable'), hasLength(2));
    });

    test('AST depth over 32 is an expression error', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {'expression': '${'(' * 40}1${')' * 40}'},
      });
      expect(hasError(v, 'expression_error'), isTrue);
    });

    test('unknown \$param binding', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          {
            'id': 'p',
            'type': 'point',
            'at': [
              {r'$param': 'missing'},
              0,
            ],
          },
        ],
      });
      expect(hasError(v, 'unknown_parameter'), isTrue);
    });

    test('slider id must match a model parameter', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'controls': [
          {
            'id': 'a',
            'kind': 'slider',
            'label': 'a',
            'min': 0,
            'max': 1,
            'step': 0.1,
            'value': 0.5,
          },
        ],
      });
      expect(hasError(v, 'unknown_parameter'), isTrue);
    });

    test('slider range rules', () {
      Map<String, dynamic> sliderScene(Map<String, dynamic> slider) => {
        'v': 1,
        'kind': 'plot2d',
        'model': {
          'parameters': {'a': 1},
        },
        'controls': [slider],
      };
      const base = {
        'id': 'a',
        'kind': 'slider',
        'label': 'a',
        'min': 0,
        'max': 1,
        'step': 0.1,
        'value': 0.5,
      };
      expect(validateVisualScene(sliderScene(base)).ok, isTrue);
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, 'min': 2})),
          'invalid_range',
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, 'step': 0})),
          'invalid_range',
        ),
        isTrue,
      );
      expect(
        hasError(
          validateVisualScene(sliderScene({...base, 'value': 2})),
          'invalid_range',
        ),
        isTrue,
      );
    });

    test('choice value must be one of the options', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'controls': [
          {
            'id': 'm',
            'kind': 'choice',
            'label': '情形',
            'options': ['A', 'B'],
            'value': 'C',
          },
        ],
      });
      expect(hasError(v, 'invalid_value'), isTrue);
    });

    test('visibleWhen must reference a toggle control', () {
      final missing = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
            'p2': [1, 1],
            'visibleWhen': {'control': 'nope', 'equals': true},
          },
        ],
      });
      expect(hasError(missing, 'unknown_control'), isTrue);

      final wrongKind = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {
          'parameters': {'a': 1},
        },
        'controls': [
          {
            'id': 'a',
            'kind': 'slider',
            'label': 'a',
            'min': 0,
            'max': 1,
            'step': 0.1,
            'value': 0.5,
          },
        ],
        'elements': [
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
            'p2': [1, 1],
            'visibleWhen': {'control': 'a', 'equals': true},
          },
        ],
      });
      expect(hasError(wrongKind, 'unknown_control'), isTrue);
    });

    test('timeline references', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'timeline': {
          'durationMs': 1000,
          'tracks': [
            {
              'id': 't1',
              'target': 'ghost',
              'from': 0,
              'to': 1,
              'startMs': 0,
              'endMs': 500,
            },
          ],
          'steps': [
            {
              'atMs': 2000,
              'show': ['ghost'],
            },
          ],
        },
      });
      expect(hasError(v, 'invalid_track_target'), isTrue);
      expect(hasError(v, 'invalid_range'), isTrue); // atMs out of range
      expect(hasError(v, 'unknown_element_reference'), isTrue);
    });

    test('track window must be inside the duration', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {
          'parameters': {'a': 1},
        },
        'controls': [
          {
            'id': 'a',
            'kind': 'slider',
            'label': 'a',
            'min': 0,
            'max': 1,
            'step': 0.1,
            'value': 0.5,
          },
        ],
        'timeline': {
          'durationMs': 1000,
          'tracks': [
            {
              'id': 't1',
              'target': 'a',
              'from': 0,
              'to': 1,
              'startMs': 800,
              'endMs': 800,
            },
          ],
        },
      });
      expect(hasError(v, 'invalid_range'), isTrue);
    });
  });

  group('validateVisualScene: resource limits', () {
    test('too many elements', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'elements': [
          for (var i = 0; i < 257; i++)
            {
              'id': 'p$i',
              'type': 'point',
              'at': [0, 0],
            },
        ],
      });
      expect(hasError(v, 'limit_exceeded'), isTrue);
    });

    test('too many controls, tracks and steps', () {
      final controls = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'controls': [
          for (var i = 0; i < 13; i++)
            {'id': 't$i', 'kind': 'toggle', 'label': 'x', 'value': true},
        ],
      });
      expect(hasError(controls, 'limit_exceeded'), isTrue);

      final tracks = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'model': {
          'parameters': {'a': 1},
        },
        'controls': [
          {
            'id': 'a',
            'kind': 'slider',
            'label': 'a',
            'min': 0,
            'max': 1,
            'step': 0.1,
            'value': 0.5,
          },
        ],
        'timeline': {
          'durationMs': 1000,
          'tracks': [
            for (var i = 0; i < 33; i++)
              {
                'id': 't$i',
                'target': 'a',
                'from': 0,
                'to': 1,
                'startMs': 0,
                'endMs': 10,
              },
          ],
        },
      });
      expect(hasError(tracks, 'limit_exceeded'), isTrue);

      final steps = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'timeline': {
          'durationMs': 1000,
          'steps': [
            for (var i = 0; i < 31; i++) {'atMs': i},
          ],
        },
      });
      expect(hasError(steps, 'limit_exceeded'), isTrue);
    });

    test('plot samples over the cap', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'plot2d',
        'elements': [
          {'id': 'p', 'type': 'plot', 'expression': 'x', 'samples': 4097},
        ],
      });
      expect(hasError(v, 'invalid_range'), isTrue);
    });

    test('scene JSON over 64 KiB', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'title': 'x' * 70000,
      });
      expect(hasError(v, 'scene_too_large'), isTrue);
    });
  });

  group('validateVisualScene: warnings', () {
    test('view much larger than content', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'title': 't',
        'view': {
          'x': [-100, 100],
          'y': [-100, 100],
        },
        'elements': [
          {
            'id': 'l',
            'type': 'line',
            'p1': [0, 0],
            'p2': [1, 1],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, 'view_much_larger_than_content'), isTrue);
    });

    test('element outside the view', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'title': 't',
        'view': {
          'x': [-1, 1],
          'y': [-1, 1],
        },
        'elements': [
          {
            'id': 'p',
            'type': 'point',
            'at': [5, 5],
          },
        ],
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, 'element_outside_view'), isTrue);
    });

    test('steps out of order warn', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'title': 't',
        'timeline': {
          'durationMs': 1000,
          'steps': [
            {'atMs': 500},
            {'atMs': 100},
          ],
        },
      });
      expect(v.ok, isTrue);
      expect(hasWarning(v, 'steps_out_of_order'), isTrue);
    });
  });

  group('validateVisualScene: malformed input never throws', () {
    test('wrong types everywhere produce issues, not exceptions', () {
      final v = validateVisualScene({
        'v': 1,
        'kind': 'geometry',
        'model': 'x',
        'view': [1, 2],
        'elements': [
          {'id': 1, 'type': 2},
          'not-a-map',
          {'id': 'c', 'type': 'circle', 'center': 'o', 'r': 'big'},
          {'id': 'g', 'type': 'group', 'children': 'nope'},
        ],
        'controls': 'nope',
        'timeline': 42,
        'annotations': [
          {'at': 'x'},
        ],
        'meta': ['alt'],
      });
      expect(v.ok, isFalse);
      expect(v.errors, isNotEmpty);
      expect(v.verificationStatus, 'unverified');
    });

    test(
      'deeply nested groups report an error instead of recursing forever',
      () {
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

        final v = validateVisualScene({
          'v': 1,
          'kind': 'geometry',
          'elements': [nestedGroup(50)],
        });
        expect(v.ok, isFalse);
        expect(v.errors.any((e) => e.message.contains('嵌套过深')), isTrue);
      },
    );
  });
}
