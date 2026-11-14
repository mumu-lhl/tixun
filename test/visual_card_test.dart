import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_animator.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/features/visual/visual_card.dart';

/// A scene whose first step hides `e1` at `atMs` 0.
VisualScene _stepScene() => VisualScene.fromJson({
  'v': 1,
  'kind': 'geometry',
  'title': '步骤图',
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
        'show': ['e1'],
        'hide': [],
        'note': '第二步',
      },
    ],
  },
  'meta': {'alt': '步骤演示'},
});

VisualPainter _cardPainter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  return visual.single.painter as VisualPainter;
}

/// The fullscreen page's painter: with the fullscreen route open the
/// card behind it still paints, so the fullscreen painter is the last
/// VisualPainter in the tree.
VisualPainter _fullscreenPainter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  final visual = paints.where((p) => p.painter is VisualPainter).toList();
  return visual.last.painter as VisualPainter;
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
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

  testWidgets('card applies the first step hiding at time 0', (tester) async {
    await _pumpCard(tester, VisualCard(scene: _stepScene()));
    // The card renders the t=0 frame, so the step-0 hide applies here
    // exactly as the fullscreen page shows it at time 0.
    expect(_cardPainter(tester).hiddenElementIds, {'e1'});
    expect(_cardPainter(tester).timeMs, 0);
    expect(_cardPainter(tester).stepIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card exposes meta.alt as the image semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpCard(
      tester,
      VisualCard(
        scene: VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
          'title': '标题',
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
          ],
          'meta': {'alt': '图的说明'},
        }),
      ),
    );
    // The title ('标题') and the alt text ('图的说明') differ, so the
    // semantics label must be the alt text, not the title.
    expect(find.bySemanticsLabel('图的说明'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dispose before the test ends: the framework verifies all
    // semantics handles are disposed at the end of the test body.
    handle.dispose();
  });

  testWidgets('card shows a default title with neither title nor alt', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      VisualCard(
        scene: VisualScene.fromJson({
          'v': 1,
          'kind': 'geometry',
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
          ],
        }),
      ),
    );
    expect(find.text('未命名图形'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card draws the selected point and region markers', (
    tester,
  ) async {
    const sceneJson = {
      'v': 1,
      'kind': 'geometry',
      'title': '选择',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'r1',
          'type': 'polygon',
          'points': [
            [-1, -1],
            [1, -1],
            [1, 1],
            [-1, 1],
          ],
          'fill': true,
        },
      ],
      'meta': {'alt': '选择'},
    };
    final scene = VisualScene.fromJson(sceneJson);
    await _pumpCard(
      tester,
      VisualCard(
        scene: scene,
        selectedPoint: const Offset(0, 0),
        selectedRegionId: 'r1',
      ),
    );
    expect(find.byKey(const Key('visual-selection-point')), findsOneWidget);
    expect(find.byKey(const Key('visual-selection-region')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card reports no step as the shared sentinel', (tester) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '静态',
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
      ],
      'meta': {'alt': '静态'},
    });
    await _pumpCard(tester, VisualCard(scene: scene));
    // No timeline at all: the painter gets the animator's no-step
    // sentinel, never 0 (0 is a real first step).
    expect(_cardPainter(tester).stepIndex, visualNoStepIndex);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card labels follow a dragged point and are not clipped', (
    tester,
  ) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '标签',
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
        {
          'id': 'l1',
          'type': 'math_label',
          'at': [1, 1],
          'tex': 'x',
        },
      ],
      'meta': {'alt': '标签'},
    });
    ui.Offset labelPosition(WidgetTester t) {
      final positioned = t.widget<Positioned>(
        find.ancestor(of: find.byType(Math), matching: find.byType(Positioned)),
      );
      return ui.Offset(positioned.left ?? 0, positioned.top ?? 0);
    }

    await _pumpCard(tester, VisualCard(scene: scene));
    // Labels are centered on their anchor: the canvas Stack must not
    // clip, or a label on the edge is cut in half.
    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(AspectRatio),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.clipBehavior, ui.Clip.none);
    final size = tester.getSize(find.byKey(const Key('visual-canvas-paint')));
    final mapper = VisualCoordinateMapper.fromScene(scene, size);
    expect(
      labelPosition(tester).dx,
      closeTo(mapper.modelToCanvas(const ui.Offset(1, 1)).dx, 0.5),
    );
    expect(
      labelPosition(tester).dy,
      closeTo(mapper.modelToCanvas(const ui.Offset(1, 1)).dy, 0.5),
    );

    // The same label, with the point dragged to (2, 2): the label
    // follows the point instead of staying at the old anchor.
    await _pumpCard(
      tester,
      VisualCard(scene: scene, pointOverrides: const {'p1': ui.Offset(2, 2)}),
    );
    expect(
      labelPosition(tester).dx,
      closeTo(mapper.modelToCanvas(const ui.Offset(2, 2)).dx, 0.5),
    );
    expect(
      labelPosition(tester).dy,
      closeTo(mapper.modelToCanvas(const ui.Offset(2, 2)).dy, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen with dragging disabled cannot move a point', (
    tester,
  ) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '拖点',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'p1',
          'type': 'point',
          'at': [0, 0],
          'draggable': true,
        },
      ],
      'meta': {'alt': '拖点'},
    });
    await _pumpCard(
      tester,
      VisualCard(scene: scene, fullscreenAllowDrag: false),
    );
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    // No reset-drag button: there is nothing to reset.
    expect(find.byKey(const Key('visual-reset-drag')), findsNothing);
    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')).last,
    );
    await tester.dragFrom(center, const Offset(90, 0));
    await tester.pump();
    expect(_fullscreenPainter(tester).pointOverrides, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone fullscreen still allows dragging a point', (
    tester,
  ) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '拖点',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'p1',
          'type': 'point',
          'at': [0, 0],
          'draggable': true,
        },
      ],
      'meta': {'alt': '拖点'},
    });
    await _pumpCard(tester, VisualCard(scene: scene));
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')).last,
    );
    await tester.dragFrom(center, const Offset(90, 0));
    await tester.pump();
    final overrides = _fullscreenPainter(tester).pointOverrides;
    expect(overrides.keys, ['p1']);
    expect(overrides['p1']!.dx, greaterThan(1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the canvas mid-drag still ends the drag', (
    tester,
  ) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '拖点',
      'view': {
        'x': [-3, 3],
        'y': [-3, 3],
      },
      'elements': [
        {
          'id': 'p1',
          'type': 'point',
          'at': [0, 0],
          'draggable': true,
        },
      ],
      'meta': {'alt': '拖点'},
    });
    final ended = <String>[];
    final show = ValueNotifier<bool>(true);
    await _pumpCard(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (context, visible, _) {
          if (!visible) return const SizedBox.shrink();
          return VisualCard(
            scene: scene,
            dragEnabled: true,
            onDragEnd: (id) => ended.add(id),
          );
        },
      ),
    );
    final center = tester.getCenter(
      find.byKey(const Key('visual-canvas-paint')),
    );
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(ended, isEmpty);
    // Remove the canvas mid-drag: without the dispose fallback the
    // drag would never end and the position would be lost (Flutter
    // does not deliver onPanCancel on dispose — verified by probe).
    show.value = false;
    await tester.pump();
    expect(ended, ['p1']);
    await gesture.up();
    await tester.pump();
    expect(ended, ['p1']);
    show.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen shows the schematic note', (tester) async {
    final scene = VisualScene.fromJson({
      'v': 1,
      'kind': 'geometry',
      'title': '示意',
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
      ],
      'meta': {'alt': '示意', 'schematic': true},
    });
    await _pumpCard(tester, VisualCard(scene: scene));
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    // The note is inside the fullscreen page's own Scaffold (the card
    // behind the route shows it too).
    expect(
      find.descendant(
        of: find.byType(Scaffold).last,
        matching: find.text('示意图，不按比例'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
