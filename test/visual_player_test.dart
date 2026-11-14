import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/features/visual/visual_card.dart';

VisualScene _playerScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '动画演示',
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
      {
        'atMs': 5000,
        'show': ['e2'],
        'hide': [],
        'note': '第三步',
      },
    ],
  },
  'meta': {'alt': '动画演示'},
});

VisualScene _staticScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'plot2d',
  'title': '静态',
  'model': {
    'expression': 'x^2',
    'parameters': {'a': 1.0},
  },
  'view': {
    'x': [-3, 3],
    'y': [-3, 3],
  },
  'meta': {'alt': '静态'},
});

VisualPainter _fullscreenPainter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  // Sliders paint their own CustomPaints too; only the canvas one
  // carries a VisualPainter.
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  return visual.last.painter as VisualPainter;
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

  testWidgets('card shows a play affordance only with a timeline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('visual-play-card')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _staticScene())),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('visual-play-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen player shows play button and seek slider', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(find.byKey(const Key('visual-play-pause')), findsOneWidget);
    expect(find.byKey(const Key('visual-seek')), findsOneWidget);
    expect(find.byKey(const Key('visual-time-label')), findsOneWidget);
    expect(find.text('0.0s / 5.0s'), findsOneWidget);
    expect(find.byKey(const Key('visual-next-step')), findsOneWidget);
    expect(find.text('第一步'), findsOneWidget);
    // At time 0 the first step hides e1.
    expect(_fullscreenPainter(tester).hiddenElementIds, {'e1'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping play advances the painter timeMs', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(_fullscreenPainter(tester).timeMs, 0);
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_fullscreenPainter(tester).timeMs, greaterThan(0));
    expect(find.text('1.0s / 5.0s'), findsOneWidget);
    // The track drives parameter `a` from 1 towards 3.
    expect(_fullscreenPainter(tester).parameters['a'], greaterThan(1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the seek slider sets timeMs', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(_fullscreenPainter(tester).timeMs, 0);
    final sliderCenter = tester.getCenter(find.byKey(const Key('visual-seek')));
    await tester.dragFrom(sliderCenter, const Offset(60, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).timeMs, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('next-step button applies the step show/hide', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(_fullscreenPainter(tester).hiddenElementIds, {'e1'});
    await tester.tap(find.byKey(const Key('visual-next-step')));
    await tester.pump();
    // Jumped to step 2 at 2500ms: e1 re-shown, e2 hidden.
    expect(_fullscreenPainter(tester).timeMs, 2500);
    expect(_fullscreenPainter(tester).hiddenElementIds, {'e2'});
    expect(find.text('2.5s / 5.0s'), findsOneWidget);
    expect(find.text('第二步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playback at 0.5x advances half as fast', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    await tester.tap(find.byKey(const Key('visual-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5×').last);
    await tester.pumpAndSettle();
    expect(find.text('0.5×'), findsOneWidget);

    // At 0.5×, one second of wall time advances the animation half a
    // second.
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0.5s / 5.0s'), findsOneWidget);
    // The track drives `a` from 1 to 3 over 5 s: at 0.5 s it is 1.2.
    expect(_fullscreenPainter(tester).parameters['a'], closeTo(1.2, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playback speed changes the rate', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    // Default speed is 1×.
    expect(find.byKey(const Key('visual-speed-label')), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.byKey(const Key('visual-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2×').last);
    await tester.pumpAndSettle();
    expect(find.text('2×'), findsOneWidget);

    // At 2×, one second of wall time advances the animation two seconds.
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2.0s / 5.0s'), findsOneWidget);
    // The track drives `a` from 1 to 3 over 5 s: at 2 s it is 1.8.
    expect(_fullscreenPainter(tester).parameters['a'], closeTo(1.8, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing speed while playing keeps the position', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0.5s / 5.0s'), findsOneWidget);
    // No pumpAndSettle while the animation runs: it never settles.
    // The first pump after opening the menu only starts the menu's
    // 300 ms entrance-animation ticker (elapsed 0); the menu settles
    // after 300 ms of further pumps, so advance it in 100 ms steps
    // (300 ms of scene time at 1×) before tapping the item.
    await tester.tap(find.byKey(const Key('visual-speed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('2×'));
    await tester.pump();
    // The menu item is still animating out, so assert the button label
    // itself rather than counting '2×' widgets.
    expect(
      tester.widget<Text>(find.byKey(const Key('visual-speed-label'))).data,
      '2×',
    );
    // Half a second of wall time at 2× adds a full second of scene
    // time: 0.5 + 0.3 (menu animation at 1×) + 1.0 = 1.8 s.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1.8s / 5.0s'), findsOneWidget);
    // The track drives `a` from 1 to 3 over 5 s: at 1.8 s it is 1.72.
    expect(_fullscreenPainter(tester).parameters['a'], closeTo(1.72, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch zoom clamps to 0.5x and 4x', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')).last,
    );
    // Spread 100 px apart to 800 px apart: ratio 8, clamped to 4×.
    final first = await tester.startGesture(center + const Offset(-50, 0));
    final second = await tester.startGesture(center + const Offset(50, 0));
    await first.moveBy(const Offset(-350, 0));
    await second.moveBy(const Offset(350, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, 4.0);
    await first.up();
    await second.up();
    await tester.pump();
    await tester.tap(find.byKey(const Key('visual-reset-view')));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, 1.0);

    // Pinch 100 px apart to 10 px apart: ratio 0.1, clamped to 0.5×.
    final third = await tester.startGesture(center + const Offset(-50, 0));
    final fourth = await tester.startGesture(center + const Offset(50, 0));
    await third.moveBy(const Offset(45, 0));
    await fourth.moveBy(const Offset(-45, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, 0.5);
    await third.up();
    await fourth.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch zooms the canvas and the reset button restores it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    expect(_fullscreenPainter(tester).zoom, 1.0);
    expect(_fullscreenPainter(tester).pan, Offset.zero);
    // Two fingers 100 px apart on the canvas, spread to 200 px.
    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')),
    );
    final first = await tester.startGesture(center + const Offset(-50, 0));
    final second = await tester.startGesture(center + const Offset(50, 0));
    await first.moveBy(const Offset(-50, 0));
    await second.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, closeTo(2.0, 0.01));
    // A symmetric spread keeps the midpoint (and the pan) still.
    expect(_fullscreenPainter(tester).pan.dx, closeTo(0, 0.5));
    await first.up();
    await second.up();
    await tester.pump();
    await tester.tap(find.byKey(const Key('visual-reset-view')));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, 1.0);
    expect(_fullscreenPainter(tester).pan, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-finger drag pans the view', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')),
    );
    final first = await tester.startGesture(center + const Offset(-50, 0));
    final second = await tester.startGesture(center + const Offset(50, 0));
    // Both fingers move right together: distance (and zoom) unchanged.
    await first.moveBy(const Offset(40, 0));
    await second.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).zoom, closeTo(1.0, 0.01));
    expect(_fullscreenPainter(tester).pan.dx, closeTo(40, 0.5));
    await first.up();
    await second.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('parameter slider tracks the animation to its end value', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    await _openFullscreen(tester);

    // Play to the end (fake clock: deterministic).
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('5.0s / 5.0s'), findsOneWidget);
    // The track drives `a` from 1 to 3; the parameter slider below the
    // canvas must show the same end value as the painter.
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    final paramSlider = sliders.firstWhere(
      (s) => s.key != const Key('visual-seek'),
    );
    expect(paramSlider.value, 3.0);
    expect(paramSlider.value, _fullscreenPainter(tester).parameters['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disableAnimations blocks autoplay and play, not seek', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: VisualCard(scene: _playerScene())),
      ),
    );
    await tester.pump();
    // The card play button requests autoplay, but animations are
    // disabled: the fullscreen page must open paused at time 0.
    await tester.tap(find.byKey(const Key('visual-play-card')));
    await tester.pumpAndSettle();
    expect(_fullscreenPainter(tester).timeMs, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(_fullscreenPainter(tester).timeMs, 0);

    // Tapping the player play button must not start playback either:
    // with animations disabled the button is greyed out, not a tap
    // that silently does nothing.
    final playButton = tester.widget<IconButton>(
      find.byKey(const Key('visual-play-pause')),
    );
    expect(playButton.onPressed, isNull);
    await tester.tap(find.byKey(const Key('visual-play-pause')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_fullscreenPainter(tester).timeMs, 0);

    // Manual seek still works.
    final sliderCenter = tester.getCenter(find.byKey(const Key('visual-seek')));
    await tester.dragFrom(sliderCenter, const Offset(60, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).timeMs, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
