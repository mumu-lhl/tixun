import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/validation/visual_quality.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';

/// P2 coverage for the `point_outside_view` boundary and the resource
/// limits: scene 64 KiB, elements 256, single-curve samples 4096,
/// controls 12, tracks 32, steps 30. Every test checks both sides of
/// the boundary (at the limit passes, one past it fails).

Map<String, dynamic> _baseScene({
  List<Map<String, dynamic>>? elements,
  Map<String, dynamic>? model,
  List<Map<String, dynamic>>? controls,
  Map<String, dynamic>? timeline,
  String? title,
}) => {
  'v': 1,
  'kind': 'geometry',
  'title': ?title,
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'model': ?model,
  'elements': elements ?? [],
  'controls': ?controls,
  'timeline': ?timeline,
  'meta': {'alt': '边界'},
};

Map<String, dynamic> _point(String id, double x, double y) => {
  'id': id,
  'type': 'point',
  'at': [x, y],
};

void main() {
  group('point_outside_view boundary', () {
    test('a point exactly on the view edge is inside', () {
      final scene = VisualScene.fromJson(
        _baseScene(
          elements: [
            _point('p1', 3, 0),
            _point('p2', -3, -3),
            _point('p3', 0, 3),
          ],
        ),
      );
      final issues = checkVisualQuality(scene);
      expect(issues.where((i) => i.code == 'point_outside_view'), isEmpty);
    });

    test('a point just past the view edge is outside', () {
      final scene = VisualScene.fromJson(
        _baseScene(elements: [_point('p1', 3.0001, 0)]),
      );
      final issues = checkVisualQuality(scene);
      expect(
        issues.where((i) => i.code == 'point_outside_view').map((i) => i.path),
        ['p1'],
      );
    });

    test('a point just past the lower edge is outside', () {
      final scene = VisualScene.fromJson(
        _baseScene(elements: [_point('p1', 0, -3.0001)]),
      );
      expect(
        checkVisualQuality(scene)
            .where((i) => i.code == 'point_outside_view')
            .length,
        1,
      );
    });
  });

  group('scene size limit (64 KiB)', () {
    /// A scene whose `jsonEncode` output is exactly [target] UTF-8
    /// bytes, padded with a long ASCII title (one byte per character).
    /// The limit counts UTF-8 bytes, not UTF-16 code units.
    Map<String, dynamic> paddedScene(int target) {
      final base = _baseScene(title: 'x');
      final baseLength = utf8.encode(jsonEncode(base)).length;
      final pad = target - baseLength + 1;
      return _baseScene(title: 'x' * pad);
    }

    test('exactly 65536 UTF-8 bytes passes', () {
      final json = paddedScene(65536);
      expect(utf8.encode(jsonEncode(json)).length, 65536);
      final v = validateVisualScene(json);
      expect(v.errors.map((e) => e.code), isNot(contains('scene_too_large')));
      expect(v.ok, isTrue);
    });

    test('65537 UTF-8 bytes fails with scene_too_large', () {
      final json = paddedScene(65537);
      expect(utf8.encode(jsonEncode(json)).length, 65537);
      final v = validateVisualScene(json);
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('scene_too_large'));
    });

    test('CJK text counts as multiple bytes, not one unit each', () {
      // The base scene carries a CJK alt ('边界'): 2 code units but 6
      // UTF-8 bytes. A scene padded to exactly 65536 code units is
      // 65540 bytes, so it is over the limit even though its
      // `jsonEncode(...).length` says 65536.
      final base = _baseScene(title: 'x');
      final baseLength = jsonEncode(base).length;
      final pad = 65536 - baseLength + 1;
      final json = _baseScene(title: 'x' * pad);
      expect(jsonEncode(json).length, 65536);
      expect(utf8.encode(jsonEncode(json)).length, 65540);
      final v = validateVisualScene(json);
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('scene_too_large'));
    });
  });

  group('element count limit (256)', () {
    List<Map<String, dynamic>> points(int n) => [
      for (var i = 0; i < n; i++) _point('p$i', 0, 0),
    ];

    test('256 elements pass', () {
      final v = validateVisualScene(_baseScene(elements: points(256)));
      expect(v.ok, isTrue);
    });

    test('257 elements fail with limit_exceeded', () {
      final v = validateVisualScene(_baseScene(elements: points(257)));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('limit_exceeded'));
    });

    test('group children count towards the limit', () {
      final v = validateVisualScene(
        _baseScene(
          elements: [
            {'id': 'g', 'type': 'group', 'children': points(256)},
          ],
        ),
      );
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('limit_exceeded'));
    });
  });

  group('plot samples limit (4096)', () {
    Map<String, dynamic> plotScene(int samples) => _baseScene(
      elements: [
        {'id': 'pl', 'type': 'plot', 'expression': 'x', 'samples': samples},
      ],
    );

    test('4096 samples pass', () {
      expect(validateVisualScene(plotScene(4096)).ok, isTrue);
    });

    test('4097 samples fail with invalid_range', () {
      final v = validateVisualScene(plotScene(4097));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('invalid_range'));
    });
  });

  group('control count limit (12)', () {
    List<Map<String, dynamic>> sliders(int n) => [
      for (var i = 0; i < n; i++)
        {
          'id': 's$i',
          'kind': 'slider',
          'label': 's$i',
          'min': 0,
          'max': 1,
          'step': 0.1,
          'value': 0,
        },
    ];

    Map<String, dynamic> sceneWithControls(int n) => _baseScene(
      model: {
        'parameters': {for (var i = 0; i < n; i++) 's$i': 0},
      },
      controls: sliders(n),
    );

    test('12 controls pass', () {
      expect(validateVisualScene(sceneWithControls(12)).ok, isTrue);
    });

    test('13 controls fail with limit_exceeded', () {
      final v = validateVisualScene(sceneWithControls(13));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('limit_exceeded'));
    });
  });

  group('track and step limits (32 / 30)', () {
    Map<String, dynamic> timelineScene({
      required int tracks,
      required int steps,
    }) => _baseScene(
      model: {
        'parameters': {'a': 0},
      },
      controls: [
        {
          'id': 'a',
          'kind': 'slider',
          'label': 'a',
          'min': -10,
          'max': 10,
          'step': 0.1,
          'value': 0,
        },
      ],
      timeline: {
        'durationMs': 4000,
        'tracks': [
          for (var i = 0; i < tracks; i++)
            {
              'id': 't$i',
              'target': 'a',
              'from': 0,
              'to': 1,
              'startMs': 0,
              'endMs': 4000,
            },
        ],
        'steps': [
          for (var i = 0; i < steps; i++)
            {'atMs': 0, 'show': [], 'hide': [], 'note': '第 $i 步'},
        ],
      },
    );

    test('32 tracks and 30 steps pass', () {
      expect(
        validateVisualScene(timelineScene(tracks: 32, steps: 30)).ok,
        isTrue,
      );
    });

    test('33 tracks fail with limit_exceeded', () {
      final v = validateVisualScene(timelineScene(tracks: 33, steps: 0));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('limit_exceeded'));
    });

    test('31 steps fail with limit_exceeded', () {
      final v = validateVisualScene(timelineScene(tracks: 0, steps: 31));
      expect(v.ok, isFalse);
      expect(v.errors.map((e) => e.code), contains('limit_exceeded'));
    });
  });
}
