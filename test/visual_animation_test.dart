import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';

VisualScene _animatedScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '动画',
  'model': {
    'expression': 'a*x',
    'parameters': {'a': 1.0, 'b': 2.0},
  },
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'e1',
      'type': 'point',
      'at': [1, 1],
    },
    {
      'id': 'e2',
      'type': 'point',
      'at': [2, 2],
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
    {
      'id': 'b',
      'kind': 'slider',
      'label': 'b',
      'min': 0,
      'max': 10,
      'step': 1,
      'value': 2,
    },
    {'id': 'showAux', 'kind': 'toggle', 'label': '辅助线', 'value': true},
  ],
  'timeline': {
    'durationMs': 1000,
    'tracks': [
      {
        'id': 't1',
        'target': 'a',
        'from': 0,
        'to': 10,
        'startMs': 0,
        'endMs': 1000,
      },
      {
        'id': 't2',
        'target': 'b',
        'from': 2,
        'to': 12,
        'startMs': 200,
        'endMs': 800,
      },
    ],
    'steps': [
      {
        'atMs': 0,
        'show': [],
        'hide': ['e1'],
        'note': '开始',
      },
      {
        'atMs': 500,
        'show': ['e1'],
        'hide': ['e2'],
        'note': '中间',
      },
      {
        'atMs': 1000,
        'show': ['e2'],
        'hide': [],
        'note': '结束',
      },
    ],
  },
  'meta': {'alt': '动画测试'},
});

/// Two steps that only hide (the second never re-shows the first
/// step's element): the cumulative frame at step 1 hides both.
VisualScene _cumulativeScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'geometry',
  'title': '累积',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'e1',
      'type': 'point',
      'at': [1, 1],
    },
    {
      'id': 'e2',
      'type': 'point',
      'at': [2, 2],
    },
  ],
  'timeline': {
    'durationMs': 1000,
    'steps': [
      {
        'atMs': 0,
        'show': [],
        'hide': ['e1'],
        'note': '第一步',
      },
      {
        'atMs': 500,
        'show': [],
        'hide': ['e2'],
        'note': '第二步',
      },
    ],
  },
  'meta': {'alt': '累积测试'},
});

void main() {
  test('track interpolates linearly at start/mid/end', () {
    final scene = _animatedScene();
    expect(resolveVisualFrame(scene, 0).parameters['a'], 0);
    expect(resolveVisualFrame(scene, 500).parameters['a'], 5);
    expect(resolveVisualFrame(scene, 1000).parameters['a'], 10);
  });

  test('track clamps before start and after end', () {
    final scene = _animatedScene();
    // Track t2 (target b) runs 200..800, from 2 to 12.
    expect(resolveVisualFrame(scene, 0).parameters['b'], 2);
    expect(resolveVisualFrame(scene, 199).parameters['b'], 2);
    expect(resolveVisualFrame(scene, 500).parameters['b'], 7);
    expect(resolveVisualFrame(scene, 800).parameters['b'], 12);
    expect(resolveVisualFrame(scene, 1000).parameters['b'], 12);
  });

  test('two overlapping tracks on different controls both apply', () {
    final frame = resolveVisualFrame(_animatedScene(), 500);
    expect(frame.parameters['a'], 5);
    expect(frame.parameters['b'], 7);
    expect(frame.toggles['showAux'], isTrue);
  });

  test('steps hide and re-show elements at their atMs boundaries', () {
    final scene = _animatedScene();
    expect(resolveVisualFrame(scene, 0).hiddenElementIds, {'e1'});
    expect(resolveVisualFrame(scene, 499).hiddenElementIds, {'e1'});
    // Step at 500 re-shows e1 and hides e2.
    expect(resolveVisualFrame(scene, 500).hiddenElementIds, {'e2'});
    expect(resolveVisualFrame(scene, 999).hiddenElementIds, {'e2'});
    // Step at 1000 re-shows e2.
    expect(resolveVisualFrame(scene, 1000).hiddenElementIds, isEmpty);
  });

  test('frame reports the current step index', () {
    final scene = _animatedScene();
    expect(resolveVisualFrame(scene, 0).stepIndex, 0);
    expect(resolveVisualFrame(scene, 499).stepIndex, 0);
    expect(resolveVisualFrame(scene, 500).stepIndex, 1);
    expect(resolveVisualFrame(scene, 1000).stepIndex, 2);
  });

  test('stepIndex override resolves cumulatively at that step', () {
    final frame = resolveVisualFrame(_animatedScene(), 0, 1);
    expect(frame.timeMs, 500);
    expect(frame.stepIndex, 1);
    // Tracks are evaluated at the step's atMs.
    expect(frame.parameters['a'], 5);
    // Cumulative: step 0 hides e1, step 1 shows e1 and hides e2 — the
    // same frame the time path produces at 500ms.
    expect(frame.hiddenElementIds, {'e2'});
    expect(
      frame.hiddenElementIds,
      resolveVisualFrame(_animatedScene(), 500).hiddenElementIds,
    );
  });

  test('stepIndex override keeps earlier hides that are not undone', () {
    // Step 1 hides e2 without re-showing e1: the earlier hide stays,
    // even though the explicit step is 1.
    final frame = resolveVisualFrame(_cumulativeScene(), 0, 1);
    expect(frame.timeMs, 500);
    expect(frame.stepIndex, 1);
    expect(frame.hiddenElementIds, {'e1', 'e2'});
  });

  test('stepIndex indexes the original step list', () {
    // Steps listed out of atMs order: index 0 is the atMs-500 step.
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '乱序',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'e1',
          'type': 'point',
          'at': [1, 1],
        },
        {
          'id': 'e2',
          'type': 'point',
          'at': [2, 2],
        },
      ],
      'timeline': {
        'durationMs': 1000,
        'steps': [
          {
            'atMs': 500,
            'show': [],
            'hide': ['e2'],
            'note': '第二步',
          },
          {
            'atMs': 0,
            'show': [],
            'hide': ['e1'],
            'note': '第一步',
          },
        ],
      },
      'meta': {'alt': '乱序测试'},
    });
    final frame = resolveVisualFrame(scene, 0, 0);
    expect(frame.timeMs, 500);
    expect(frame.stepIndex, 0);
    // Cumulative by atMs: both steps apply.
    expect(frame.hiddenElementIds, {'e1', 'e2'});
  });

  test('scene without a timeline keeps defaults and duration 0', () {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'plot2d',
      'title': '静态',
      'model': {
        'expression': 'a*x',
        'parameters': {'a': 1.0},
      },
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
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
      ],
      'meta': {'alt': '静态测试'},
    });
    expect(visualDurationMs(scene), 0);
    final frame = resolveVisualFrame(scene, 1234);
    expect(frame.parameters['a'], 1);
    expect(frame.hiddenElementIds, isEmpty);
    expect(frame.stepIndex, -1);
    expect(frame.timeMs, 1234);
  });

  test('visualDurationMs returns the timeline length', () {
    expect(visualDurationMs(_animatedScene()), 1000);
  });

  test('malformed tracks are skipped without throwing', () {
    // Built directly (fromJson would reject these): an unknown target
    // and a degenerate zero-length window.
    final scene = VisualScene(
      kind: VisualSceneKind.plot2d,
      model: const VisualModel(expression: 'a*x', parameters: {'a': 1.0}),
      controls: const [
        SliderControl(
          id: 'a',
          label: 'a',
          min: -3,
          max: 3,
          step: 0.1,
          value: 1,
        ),
      ],
      timeline: const VisualTimeline(
        durationMs: 1000,
        tracks: [
          VisualTrack(
            id: 't1',
            target: 'nope',
            from: 0,
            to: 10,
            startMs: 0,
            endMs: 1000,
          ),
          VisualTrack(
            id: 't2',
            target: 'a',
            from: 0,
            to: 10,
            startMs: 500,
            endMs: 500,
          ),
        ],
      ),
    );
    // Unknown target leaves the parameter at its default.
    expect(resolveVisualFrame(scene, 500).parameters['a'], 10);
    // Degenerate window: instant jump at startMs.
    expect(resolveVisualFrame(scene, 499).parameters['a'], 0);
    expect(resolveVisualFrame(scene, 500).parameters['a'], 10);
    // Out-of-range stepIndex falls back to time-based resolution.
    final frame = resolveVisualFrame(scene, 250, 99);
    expect(frame.timeMs, 250);
    expect(frame.stepIndex, -1);
  });
}
