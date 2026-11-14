import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
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
}
