import 'dart:convert';

import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/features/visual/visual_card.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Linux GUI: a draggable point moves and resets', (
    tester,
  ) async {
    final c = await AppController.open(demo: true);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TixunApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-chat')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat-input')),
      '请画图，画出 y = x^2 的函数图',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 100 && c.busy; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.busy, false);
    await tester.pumpAndSettle();
    final scenes = await c.visual.listByMessage(c.messages.last.id);
    expect(scenes, hasLength(1));
    // Replace the static mock scene with a geometry scene carrying one
    // draggable point (p1) and one fixed point (p2).
    final dragScene = {
      'v': 1,
      'kind': 'geometry',
      'title': '拖拽点',
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
    };
    await c.visual.revise(scenes.single.id, jsonEncode(dragScene));
    await tester.pumpAndSettle();
    expect(find.byType(VisualCard), findsOneWidget);
    await tester.ensureVisible(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();

    VisualPainter painter() {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      return visual.last.painter as VisualPainter;
    }

    Offset pointGlobal(Offset model) {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      final paint = visual.last;
      final topLeft = tester.getTopLeft(find.byWidget(paint));
      final size = tester.getSize(find.byWidget(paint));
      final scene = VisualScene.fromJson(dragScene);
      final mapper = VisualCoordinateMapper.fromScene(scene, size);
      return topLeft + mapper.modelToCanvas(model);
    }

    expect(painter().pointOverrides, isEmpty);
    // Drag p1 by (60, -30) canvas pixels.
    final start = pointGlobal(const Offset(1, 1));
    await tester.dragFrom(start, const Offset(60, -30));
    await tester.pump();
    final overrides = painter().pointOverrides;
    expect(overrides.keys, ['p1']);
    // The point moved right and up in model space.
    expect(overrides['p1']!.dx, greaterThan(1.0));
    expect(overrides['p1']!.dy, greaterThan(1.0));

    // Reset restores the scene coordinates.
    await tester.tap(find.byKey(const Key('visual-reset-drag')));
    await tester.pump();
    expect(painter().pointOverrides, isEmpty);
  });
}
