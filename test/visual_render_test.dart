import 'dart:convert';

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/core/visual/render/visual_png.dart';
import 'package:tixun/core/visual/render/visual_theme.dart';
import 'package:tixun/features/visual/visual_card.dart';

VisualScene _plotScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '二次函数',
  'model': {
    'expression': 'x^2-4',
    'parameters': {'a': 1.0},
  },
  'view': {
    'x': [-3, 3],
    'y': [-5, 6],
  },
  'meta': {'alt': '抛物线 y=x^2-4 的图像'},
});

VisualScene _geometryScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'geometry',
  'title': '三角形与圆',
  'elements': [
    {
      'id': 'tri',
      'type': 'polygon',
      'points': [
        [0, 0],
        [4, 0],
        [0, 3],
      ],
      'fill': true,
    },
    {
      'id': 'circ',
      'type': 'circle',
      'center': [2, 1.5],
      'r': 1,
      'style': 'highlight',
    },
    {
      'id': 'label',
      'type': 'math_label',
      'at': [2, 4],
      'tex': r'x^2 + y^2 = 1',
    },
  ],
});

VisualScene _sliderScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '一次函数',
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
});

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

  // No golden tests exist in this repo: the painter is covered by these
  // behaviour tests plus the math unit tests (sampling / expressions).
  test('coordinate mapper preserves aspect and flips y up', () {
    final scene = _plotScene();
    final mapper = VisualCoordinateMapper.fromScene(
      scene,
      const Size(600, 400),
    );
    // view 6 x 11 into 600 x 400: scale = min(100, 400/11) = 400/11.
    final scale = 400 / 11;
    expect(mapper.scale, closeTo(scale, 1e-9));
    final origin = mapper.modelToCanvas(Offset.zero);
    expect(origin.dx, closeTo(300, 1e-9));
    expect(origin.dy, closeTo(400 - 5 * scale, 1e-9));
    // Top-left model corner maps to the top of the letterboxed rect.
    final topLeft = mapper.modelToCanvas(const Offset(-3, 6));
    expect(topLeft.dy, closeTo(0, 1e-9));
  });

  test('canvasToModel inverts modelToCanvas, including the letterbox', () {
    final scene = _plotScene();
    final mapper = VisualCoordinateMapper.fromScene(
      scene,
      const Size(600, 400),
    );
    for (final model in [
      Offset.zero,
      const Offset(-3, 6),
      const Offset(3, -5),
      const Offset(1.25, -2.5),
    ]) {
      final back = mapper.canvasToModel(mapper.modelToCanvas(model));
      expect(back.dx, closeTo(model.dx, 1e-9));
      expect(back.dy, closeTo(model.dy, 1e-9));
    }
    // The letterboxed left margin maps outside the view's x range.
    expect(mapper.canvasToModel(const Offset(0, 200)).dx, lessThan(-3));
  });

  test('canvasToModel inverts modelToCanvas under zoom and pan', () {
    final scene = _plotScene();
    final mapper = VisualCoordinateMapper.fromScene(
      scene,
      const Size(800, 600),
      zoom: 2.0,
      pan: const Offset(30, -20),
    );
    for (final model in [
      const Offset(0, 0),
      const Offset(2, -3),
      const Offset(-1.5, 4),
    ]) {
      final back = mapper.canvasToModel(mapper.modelToCanvas(model));
      expect(back.dx, closeTo(model.dx, 1e-9));
      expect(back.dy, closeTo(model.dy, 1e-9));
    }
    // Zooming about the view centre keeps the centre fixed: the view
    // centre (0, 0.5) maps to the same canvas point at zoom 1 and 2.
    final fit = VisualCoordinateMapper.fromScene(scene, const Size(800, 600));
    expect(
      mapper.modelToCanvas(const Offset(0, 0.5)).dx,
      closeTo(fit.modelToCanvas(const Offset(0, 0.5)).dx + 30, 1e-9),
    );
    expect(
      mapper.modelToCanvas(const Offset(0, 0.5)).dy,
      closeTo(fit.modelToCanvas(const Offset(0, 0.5)).dy - 20, 1e-9),
    );
  });

  test('renderVisualPng returns PNG bytes', () async {
    const palette = VisualPalette(
      primary: Color(0xff226450),
      highlight: Color(0xff7d5700),
      muted: Color(0xff767680),
      success: Color(0xff226450),
      danger: Color(0xffb3261e),
      axis: Color(0x991c1b1f),
      grid: Color(0xffd0d0d0),
      background: Color(0xfffafbf8),
      onBackground: Color(0xff1c1b1f),
      textMuted: Color(0xff767680),
    );
    final bytes = await renderVisualPng(_plotScene(), palette);
    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
  });

  test('renderVisualPng renders the frame at the requested time', () async {
    const palette = VisualPalette(
      primary: Color(0xff226450),
      highlight: Color(0xff7d5700),
      muted: Color(0xff767680),
      success: Color(0xff226450),
      danger: Color(0xffb3261e),
      axis: Color(0x991c1b1f),
      grid: Color(0xffd0d0d0),
      background: Color(0xfffafbf8),
      onBackground: Color(0xff1c1b1f),
      textMuted: Color(0xff767680),
    );
    // A line whose slope the track drives from 1 to 3 over 5 seconds,
    // with a step at 2500 ms that swaps which point is shown.
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'plot2d',
      'title': '动画',
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
        'steps': [
          {
            'atMs': 0,
            'show': [],
            'hide': ['e1'],
            'note': '第一步',
          },
          {
            'atMs': 2500,
            'show': ['e1'],
            'hide': ['e2'],
            'note': '第二步',
          },
        ],
      },
      'meta': {'alt': '动画'},
    });
    final atStart = await renderVisualPng(scene, palette, timeMs: 0);
    final atStartAgain = await renderVisualPng(scene, palette, timeMs: 0);
    final atMiddle = await renderVisualPng(scene, palette, timeMs: 2500);
    final atEnd = await renderVisualPng(scene, palette, timeMs: 5000);
    // Same moment renders identically; different moments differ (the
    // slope moved and the step swapped the visible point).
    expect(atStart, atStartAgain);
    expect(atMiddle, isNot(atStart));
    expect(atEnd, isNot(atMiddle));
    // A manual parameter override wins over the animation at that time.
    final overridden = await renderVisualPng(
      scene,
      palette,
      timeMs: 2500,
      parameters: const {'a': 3.0},
    );
    expect(overridden, isNot(atMiddle));
    expect(overridden, atEnd);
  });

  testWidgets('plot2d card renders a canvas', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _plotScene())),
      ),
    );
    await tester.pump();
    expect(find.byType(VisualCard), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('二次函数'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geometry card auto-fits without a view', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _geometryScene())),
      ),
    );
    await tester.pump();
    expect(find.text('三角形与圆'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // The math label is a Math.tex overlay, not canvas paint.
    expect(find.byType(Math), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap opens fullscreen with working sliders', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _sliderScene())),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(VisualCard));
    await tester.pumpAndSettle();

    // Fullscreen page: one slider bound to parameter `a`.
    expect(find.byType(Slider), findsOneWidget);
    VisualPainter fullscreenPainter() {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      // Sliders paint their own CustomPaints too; only the canvas one
      // carries a VisualPainter.
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      return visual.last.painter as VisualPainter;
    }

    expect(fullscreenPainter().parameters['a'], 1.0);
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    expect(fullscreenPainter().parameters['a'], isNot(1.0));
    expect(tester.takeException(), isNull);
  });
}
