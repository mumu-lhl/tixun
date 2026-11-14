import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/ai/quiz_tool.dart';
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
  testWidgets('Real Linux GUI: a quiz question shows its pinned visual', (
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
    // Create a quiz question attached to the Mock scene: the executor
    // snapshots it (revision 2) and pins the question to that revision.
    final result = await executeQuizTool(
      c.practice,
      ToolCall(
        'c1',
        'create_quiz',
        jsonEncode({
          'kind': 'numeric',
          'stem': '图中抛物线与 x 轴交点的横坐标是多少？',
          'subject': '数学',
          'answers': [
            ['2'],
          ],
          'explanation': 'x^2 - 4 = 0 的根是 ±2。',
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
    // Editing the scene afterwards must not change the question's figure:
    // revise the live scene, then render the question card.
    final revised = jsonDecode(scenes.single.sceneJson) as Map<String, dynamic>;
    revised['title'] = '改过的标题';
    await c.visual.revise(visualId, jsonEncode(revised));
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
    // The card shows the pinned revision's title, not the edited one.
    expect(find.text('y = x²'), findsOneWidget);
    expect(find.text('改过的标题'), findsNothing);
    expect(find.textContaining('图中抛物线与 x 轴交点'), findsOneWidget);
  });
}
