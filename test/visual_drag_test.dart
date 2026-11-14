import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/validation/visual_validator.dart';
import 'package:tixun/features/visual/visual_card.dart';

/// A geometry scene with one draggable point (p1), one fixed point (p2),
/// and one draggable-flagged but `$param`-bound point (p3, built in code —
/// the validator rejects this combination, the widget must refuse it too).
VisualScene _dragScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'geometry',
  'title': '拖拽',
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'p1',
      'type': 'point',
      'at': [1, 1],
      'draggable': true,
      'label': 'P',
    },
    {
      'id': 'p2',
      'type': 'point',
      'at': [-1, -1],
    },
  ],
  'meta': {'alt': '拖拽点'},
});

/// A draggable-flagged but `$param`-bound point, built directly through
/// the constructors: `VisualScene.fromJson` runs the validator and
/// rejects this combination, so the constructor is the only way to reach
/// the widget's own guard.
const VisualScene _boundDragScene = VisualScene(
  kind: VisualSceneKind.geometry,
  title: '绑定点',
  model: VisualModel(expression: 'a*x', parameters: {'a': 1.0}),
  view: VisualView(x: VisualRange(-3, 3), y: VisualRange(-3, 3)),
  controls: [
    SliderControl(id: 'a', label: 'a', min: -3, max: 3, step: 0.1, value: 1),
  ],
  elements: [
    PointElement(
      id: 'p3',
      style: VisualStyle.primary,
      layer: 0,
      visible: true,
      at: VisualPoint(VisualCoord.param('a'), VisualCoord.literal(1)),
      draggable: true,
    ),
  ],
  meta: VisualMeta(alt: '绑定点'),
);

/// The drag scene plus a 5s timeline (track `a` 1→3), for the
/// drag-pauses-playback test. p1 stays draggable.
VisualScene _animatedDragScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '动画拖拽',
  'model': {
    'expression': 'a*x',
    'parameters': {'a': 1.0},
  },
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'elements': [
    {
      'id': 'p1',
      'type': 'point',
      'at': [1, 1],
      'draggable': true,
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
  ],
  'timeline': {
    'durationMs': 5000,
    'tracks': [
      {
        'id': 't1',
        'target': 'a',
        'from': 1,
        'to': 3,
        'startMs': 0,
        'endMs': 5000,
      },
    ],
    'steps': [],
  },
  'meta': {'alt': '动画拖拽'},
});

VisualPainter _fullscreenPainter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  return visual.last.painter as VisualPainter;
}

/// Global position of a model point on the fullscreen canvas, computed
/// through the same mapper the painter uses.
Offset _pointGlobal(WidgetTester tester, VisualScene scene, Offset model) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  final paint = visual.last;
  final topLeft = tester.getTopLeft(find.byWidget(paint));
  final size = tester.getSize(find.byWidget(paint));
  final mapper = VisualCoordinateMapper.fromScene(scene, size);
  return topLeft + mapper.modelToCanvas(model);
}

/// Expected model position after dragging from [startModel] by
/// [offset] canvas pixels (the drag starts on the point, so the grab
/// offset is zero).
Offset _expectedAfterDrag(
  WidgetTester tester,
  VisualScene scene,
  Offset startModel,
  Offset offset,
) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  final paint = visual.last;
  final size = tester.getSize(find.byWidget(paint));
  final mapper = VisualCoordinateMapper.fromScene(scene, size);
  return mapper.canvasToModel(mapper.modelToCanvas(startModel) + offset);
}

Future<void> _openFullscreen(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.open_in_full));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  test('point draggable defaults to false and round-trips', () {
    final element = VisualElement.fromJson({
      'id': 'p',
      'type': 'point',
      'at': [1, 2],
    }) as PointElement;
    expect(element.draggable, isFalse);
    expect(element.toJson().containsKey('draggable'), isFalse);

    final draggable = VisualElement.fromJson({
      'id': 'p',
      'type': 'point',
      'at': [1, 2],
      'draggable': true,
    }) as PointElement;
    expect(draggable.draggable, isTrue);
    expect(draggable.toJson()['draggable'], isTrue);
    final reparsed = VisualElement.fromJson(draggable.toJson()) as PointElement;
    expect(reparsed.draggable, isTrue);
    expect(reparsed.at, draggable.at);
  });

  test('validator accepts a draggable literal point', () {
    final scene = _dragScene().toJson();
    final result = validateVisualScene(scene);
    expect(result.ok, isTrue);
  });

  test('validator rejects a draggable parameter-bound point', () {
    // A raw map: VisualScene.fromJson throws before the validator
    // result is reachable, so the validator is checked directly.
    final scene = _animatedDragScene().toJson();
    (scene['elements'] as List).first['at'] = [
      {'\$param': 'a'},
      1,
    ];
    final result = validateVisualScene(scene);
    expect(result.ok, isFalse);
    expect(
      result.errors.any(
        (e) => e.code == 'invalid_value' && e.message.contains('draggable'),
      ),
      isTrue,
    );
  });

  test('validator rejects a non-boolean draggable flag', () {
    final scene = _dragScene().toJson();
    (scene['elements'] as List).first['draggable'] = 'yes';
    final result = validateVisualScene(scene);
    expect(result.ok, isFalse);
    expect(
      result.errors.any(
        (e) => e.code == 'invalid_type' && e.path == 'elements[0].draggable',
      ),
      isTrue,
    );
  });

  testWidgets('dragging a draggable point moves it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _dragScene();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    final start = _pointGlobal(tester, scene, const Offset(1, 1));
    const drag = Offset(40, -20);
    await tester.dragFrom(start, drag);
    await tester.pump();

    final overrides = _fullscreenPainter(tester).pointOverrides;
    expect(overrides.keys, ['p1']);
    final expected = _expectedAfterDrag(
      tester,
      scene,
      const Offset(1, 1),
      drag,
    );
    expect(overrides['p1']!.dx, closeTo(expected.dx, 1e-6));
    expect(overrides['p1']!.dy, closeTo(expected.dy, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a fixed point does nothing', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _dragScene();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final start = _pointGlobal(tester, scene, const Offset(-1, -1));
    await tester.dragFrom(start, const Offset(40, -20));
    await tester.pump();

    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging empty canvas space does nothing', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _dragScene();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final start = _pointGlobal(tester, scene, const Offset(0, -2));
    await tester.dragFrom(start, const Offset(40, -20));
    await tester.pump();

    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a parameter-bound point cannot be dragged', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _boundDragScene;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final start = _pointGlobal(tester, scene, const Offset(1, 1));
    await tester.dragFrom(start, const Offset(40, -20));
    await tester.pump();

    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset button restores dragged points', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _dragScene();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final start = _pointGlobal(tester, scene, const Offset(1, 1));
    await tester.dragFrom(start, const Offset(40, -20));
    await tester.pump();
    expect(_fullscreenPainter(tester).pointOverrides, isNotEmpty);

    await tester.tap(find.byKey(const Key('visual-reset-drag')));
    await tester.pump();
    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging pauses playback', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final scene = _animatedDragScene();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: scene)),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_fullscreenPainter(tester).timeMs, greaterThan(0));

    final start = _pointGlobal(tester, scene, const Offset(1, 1));
    await tester.dragFrom(start, const Offset(40, -20));
    await tester.pump();
    expect(_fullscreenPainter(tester).pointOverrides, isNotEmpty);

    // Paused: the button shows the play icon again, and time stops.
    final button = tester.widget<IconButton>(
      find.byKey(const Key('visual-play-pause')),
    );
    expect((button.icon as Icon).icon, Icons.play_arrow);
    final frozenTime = _fullscreenPainter(tester).timeMs;
    await tester.pump(const Duration(seconds: 1));
    expect(_fullscreenPainter(tester).timeMs, frozenTime);
    expect(tester.takeException(), isNull);
  });
}
