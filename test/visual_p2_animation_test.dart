import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';

/// P2 coverage for the timeline animator: resolving past the end of the
/// timeline, two tracks on the same target, and out-of-range step
/// indexes. All expectations pin the current behaviour of
/// [resolveVisualFrame].

VisualScene _scene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '动画边界',
  'model': {
    'expression': 'x',
    'parameters': {'a': 0},
  },
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'e1',
      'type': 'point',
      'at': [0, 0],
    },
    {
      'id': 'e2',
      'type': 'point',
      'at': [1, 1],
    },
  ],
  'controls': [
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
  'timeline': {
    'durationMs': 4000,
    'tracks': [
      {
        'id': 't1',
        'target': 'a',
        'from': 0,
        'to': 10,
        'startMs': 0,
        'endMs': 4000,
      },
    ],
    'steps': [
      {
        'atMs': 0,
        'show': [],
        'hide': ['e1'],
        'note': '藏起 e1',
      },
      {
        'atMs': 4000,
        'show': ['e1'],
        'hide': [],
        'note': '露出 e1',
      },
    ],
  },
  'meta': {'alt': '动画'},
});

void main() {
  group('resolving past the end of the timeline', () {
    test('time beyond durationMs clamps tracks and applies all steps', () {
      final frame = resolveVisualFrame(_scene(), 8000);
      // The track is clamped to its `to` value; both steps have
      // atMs <= 8000, and the later step re-shows e1.
      expect(frame.parameters['a'], 10);
      expect(frame.hiddenElementIds, isEmpty);
      expect(frame.timeMs, 8000);
      expect(frame.stepIndex, 1);
    });

    test('time exactly at durationMs applies the final step', () {
      final frame = resolveVisualFrame(_scene(), 4000);
      expect(frame.parameters['a'], 10);
      expect(frame.hiddenElementIds, isEmpty);
      expect(frame.stepIndex, 1);
    });

    test('mid-timeline time interpolates the track and hides e1', () {
      final frame = resolveVisualFrame(_scene(), 2000);
      expect(frame.parameters['a'], 5);
      expect(frame.hiddenElementIds, {'e1'});
      expect(frame.stepIndex, 0);
    });

    test('negative time behaves like time zero for tracks', () {
      final frame = resolveVisualFrame(_scene(), -500);
      expect(frame.parameters['a'], 0);
      expect(frame.hiddenElementIds, isEmpty);
      expect(frame.stepIndex, -1);
    });
  });

  group('two tracks on the same target', () {
    VisualScene dualTrackScene() {
      final json = _scene().toJson();
      (json['timeline'] as Map)['tracks'] = [
        {
          'id': 't1',
          'target': 'a',
          'from': 0,
          'to': 10,
          'startMs': 0,
          'endMs': 4000,
        },
        {
          'id': 't2',
          'target': 'a',
          'from': 100,
          'to': 200,
          'startMs': 0,
          'endMs': 4000,
        },
      ];
      return VisualScene.fromJson(json);
    }

    test('the later track overrides the earlier one', () {
      final scene = dualTrackScene();
      expect(resolveVisualFrame(scene, 0).parameters['a'], 100);
      expect(resolveVisualFrame(scene, 2000).parameters['a'], 150);
      expect(resolveVisualFrame(scene, 4000).parameters['a'], 200);
    });
  });

  group('stepIndex edge cases', () {
    test('a negative stepIndex falls back to the time path', () {
      final frame = resolveVisualFrame(_scene(), 1000, -1);
      // Same as resolveVisualFrame(scene, 1000): step 0 hides e1.
      expect(frame.parameters['a'], 2.5);
      expect(frame.hiddenElementIds, {'e1'});
      expect(frame.stepIndex, 0);
      expect(frame.timeMs, 1000);
    });

    test('an out-of-range stepIndex falls back to the time path', () {
      final frame = resolveVisualFrame(_scene(), 1000, 99);
      expect(frame.parameters['a'], 2.5);
      expect(frame.hiddenElementIds, {'e1'});
      expect(frame.stepIndex, 0);
      expect(frame.timeMs, 1000);
    });

    test('an explicit stepIndex resolves cumulatively at that step', () {
      final frame = resolveVisualFrame(_scene(), 0, 1);
      // Step 1 (atMs 4000) applies step 0 first, then itself: e1 is
      // hidden by step 0 and re-shown by step 1; tracks run at 4000.
      expect(frame.parameters['a'], 10);
      expect(frame.hiddenElementIds, isEmpty);
      expect(frame.timeMs, 4000);
      expect(frame.stepIndex, 1);
    });

    test('a scene without a timeline reports stepIndex -1', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'title': '无时间线',
        'elements': [
          {
            'id': 'e1',
            'type': 'point',
            'at': [0, 0],
          },
        ],
        'meta': {'alt': '无'},
      });
      final frame = resolveVisualFrame(scene, 1234);
      expect(frame.stepIndex, -1);
      expect(frame.timeMs, 1234);
      expect(frame.hiddenElementIds, isEmpty);
      expect(visualDurationMs(scene), 0);
    });
  });
}
