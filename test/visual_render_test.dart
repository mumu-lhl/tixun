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

/// Shared palette for the canvas-level tests below (same values as the
/// inline palettes above).
const _testPalette = VisualPalette(
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

VisualScene _switchScene({required bool closed, required String style}) =>
    VisualScene.fromJson({
      'v': 1,
      'kind': 'circuit',
      'title': '开关',
      'view': {
        'x': [-1, 11],
        'y': [-2, 4],
      },
      'elements': [
        {
          'id': 'sw',
          'type': 'circuit',
          'component': 'switch',
          'from': [0, 0],
          'to': [10, 0],
          'closed': closed,
          'style': style,
        },
      ],
      'meta': {'alt': '开关'},
    });

int _drawLineCount(TestRecordingCanvas canvas) => canvas.invocations
    .where((i) => i.invocation.memberName == #drawLine)
    .length;

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

  group('auto-fit pole tails', () {
    test('1/x without a view does not let pole samples stretch y', () {
      // Near-pole samples reach |y| ~ 25, but the fit follows the
      // main body instead (untrimmed, the height would be ~120).
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '反比例',
        'model': {'expression': '1/x'},
        'meta': {'alt': '反比例'},
      });
      final rect = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      ).modelRect;
      expect(rect.height, lessThan(10));
    });

    test('tan(x) without a view does not let pole samples stretch y', () {
      // Near-pole samples reach |y| ~ 35, including lone samples
      // wedged between two breaks right at a pole; those singletons
      // are dropped and every branch is trimmed to ~|y| 8, so the
      // height stays well under the untrimmed ~85.
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '正切',
        'model': {'expression': 'tan(x)'},
        'meta': {'alt': '正切'},
      });
      final rect = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      ).modelRect;
      expect(rect.height, lessThan(30));
    });

    test('a narrow peak is not mistaken for a pole singleton', () {
      // A lone peak sample on a flat baseline must stay in auto-fit:
      // its neighbours are ~0, so it is content, not pole approach.
      // If it were dropped, the view would collapse to the baseline
      // and the peak would sit outside it. (With no view the curve
      // is sampled over [-10, 10], so the nearest sample to the peak
      // is ~0.01 off-centre and the peak height is ~0.38, not 1.)
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '窄峰',
        'model': {'expression': 'exp(-((x-0.5)/0.01)^2)'},
        'meta': {'alt': '窄峰'},
      });
      final rect = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      ).modelRect;
      expect(rect.top, lessThan(0.2));
      expect(rect.bottom, greaterThan(0.3));
    });

    test('a steep continuous curve is not trimmed', () {
      // x^2 has one segment whose ends sit on the range edges: the
      // real extent y in [0, 100] survives, plus 10% padding.
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '抛物线',
        'model': {'expression': 'x^2'},
        'meta': {'alt': '抛物线'},
      });
      final rect = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      ).modelRect;
      expect(rect.height, closeTo(120, 1));
    });

    test('exp(x) is not trimmed', () {
      // Also a single segment ending on the range edges: y up to e^10.
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '指数',
        'model': {'expression': 'exp(x)'},
        'meta': {'alt': '指数'},
      });
      final rect = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      ).modelRect;
      expect(rect.height, greaterThan(20000));
    });
  });

  group('switch dashing', () {
    test('an open success-styled switch is dashed', () {
      final painter = VisualPainter(
        scene: _switchScene(closed: false, style: 'success'),
        palette: _testPalette,
        parameters: const {},
      );
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(600, 300));
      // Two switch segments, each dashed into many short lines.
      expect(_drawLineCount(canvas), greaterThan(10));
    });

    test('a closed success-styled switch is dashed', () {
      final painter = VisualPainter(
        scene: _switchScene(closed: true, style: 'success'),
        palette: _testPalette,
        parameters: const {},
      );
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(600, 300));
      expect(_drawLineCount(canvas), greaterThan(10));
    });

    test('an open primary-styled switch is solid', () {
      final painter = VisualPainter(
        scene: _switchScene(closed: false, style: 'primary'),
        palette: _testPalette,
        parameters: const {},
      );
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(600, 300));
      // Exactly one drawLine per switch segment (plus the contact dot).
      expect(_drawLineCount(canvas), 2);
    });
  });

  group('single-point segments', () {
    test('a narrow peak renders as a dot, not nothing', () {
      // The peak is narrower than the sampling step: at 1024 samples
      // it is a single isolated sample (see the probe in the review:
      // width 0.001 gives one singleton segment at y ~ 1).
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '窄峰',
        'model': {'expression': 'exp(-((x-0.50147)/0.001)^2)'},
        'view': {
          'x': [-3, 3],
          'y': [-1, 2],
        },
        'meta': {'alt': '窄峰'},
      });
      final painter = VisualPainter(
        scene: scene,
        palette: _testPalette,
        parameters: const {},
      );
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(600, 400));
      final circles = canvas.invocations
          .where((i) => i.invocation.memberName == #drawCircle)
          .toList();
      expect(circles, hasLength(1));
      // The dot sits at the peak sample.
      final mapper = VisualCoordinateMapper.fromScene(
        scene,
        const Size(600, 400),
      );
      final expected = mapper.modelToCanvas(const Offset(0.50147, 1));
      final center = circles.single.invocation.positionalArguments[0] as Offset;
      expect(center.dx, closeTo(expected.dx, 1.0));
      expect(center.dy, closeTo(expected.dy, 1.0));
    });

    test('a smooth curve paints no dots', () {
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'plot2d',
        'title': '抛物线',
        'model': {'expression': 'x^2'},
        'view': {
          'x': [-3, 3],
          'y': [-5, 6],
        },
        'meta': {'alt': '抛物线'},
      });
      final painter = VisualPainter(
        scene: scene,
        palette: _testPalette,
        parameters: const {},
      );
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(600, 400));
      expect(
        canvas.invocations.where((i) => i.invocation.memberName == #drawCircle),
        isEmpty,
      );
    });
  });
}
