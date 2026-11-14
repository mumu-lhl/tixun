import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
import 'package:tixun/core/visual/model/visual_scene.dart';
import 'package:tixun/core/visual/render/visual_painter.dart';
import 'package:tixun/features/practice/question_card.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Linux GUI: drag-to-target answers by dragging the point', (
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
    final visualId = scenes.single.id;
    // Replace the Mock scene with a draggable point at the origin.
    await c.visual.revise(
      visualId,
      jsonEncode({
        'v': 1,
        'kind': 'geometry',
        'title': '拖点图',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
        'elements': [
          {
            'id': 'p1',
            'type': 'point',
            'at': [0, 0],
            'label': 'P',
            'draggable': true,
          },
        ],
        'meta': {'alt': '拖点'},
      }),
    );
    final result = await executeQuizTool(
      c.practice,
      ToolCall(
        'c1',
        'create_quiz',
        jsonEncode({
          'kind': 'drag_to_target',
          'stem': '把点 P 拖到 (2, 0)。',
          'subject': '数学',
          'answers': [
            ['2,0'],
          ],
          'explanation': '目标在 (2, 0)。',
          'visual_id': visualId,
        }),
      ),
      sessionId: c.messages.last.sessionId,
      runId: c.messages.last.id,
      cancel: CancelToken(),
      visual: c.visual,
    );
    expect(result['ok'], true);
    final questionId = result['question_id'] as String;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: QuestionCard(questionId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('拖点图'), findsOneWidget);
    // Compute the drag in model coordinates, like the fullscreen drag
    // flow test: the canvas size depends on the real window, so the
    // pixel offset for "+2 model units" is measured, not assumed.
    VisualPainter painter() {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      return visual.last.painter as VisualPainter;
    }

    Offset pointGlobal(ui.Offset model) {
      final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final visual = paints.where((p) => p.painter is VisualPainter).toList();
      final paint = visual.last;
      final topLeft = tester.getTopLeft(find.byWidget(paint));
      final size = tester.getSize(find.byWidget(paint));
      final scene = VisualScene.fromJson({
        'v': 1,
        'kind': 'geometry',
        'view': {
          'x': [-3, 3],
          'y': [-3, 3],
        },
      });
      final mapper = VisualCoordinateMapper.fromScene(scene, size);
      return topLeft + mapper.modelToCanvas(model);
    }

    expect(painter().pointOverrides, isEmpty);
    final start = pointGlobal(const ui.Offset(0, 0));
    final end = pointGlobal(const ui.Offset(2, 0));
    // A single-jump dragFrom is enough: the canvas reports the
    // pointer-down position in onPanStart (dragStartBehavior.down),
    // so the hit test sees the press exactly on the point.
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(painter().pointOverrides.keys, ['p1']);
    expect(find.textContaining('已选点：'), findsOneWidget);
    // The card is taller than the window: scroll the submit button
    // into view before tapping it, or the tap misses.
    await tester.ensureVisible(find.byKey(const Key('submit-quiz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-quiz')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      if (find.textContaining('参考答案：').evaluate().isNotEmpty) break;
      if (i == 19) fail('the graded view never appeared');
    }
    expect((await c.practice.detail(questionId)).latest!.correct, true);
    expect(tester.takeException(), isNull);
  });
}
