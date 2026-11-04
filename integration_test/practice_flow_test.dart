import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/practice/question_card.dart';

Future<void> capture(String name) async {
  if (!Platform.isLinux) return;
  await Directory('artifacts/gui-practice').create(recursive: true);
  final magick = await Process.run('which', ['magick']);
  final result = await Process.run(magick.exitCode == 0 ? 'magick' : 'import', [
    if (magick.exitCode == 0) 'import',
    '-window',
    'root',
    'artifacts/gui-practice/$name.png',
  ]);
  expect(result.exitCode, 0, reason: 'capture $name');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Wrong problem, independent redo, saved feedback, Chat variant and clickable quiz',
    (tester) async {
      final c = await AppController.open(demo: true);
      final container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TixunApp(),
        ),
      );
      await tester.pumpAndSettle();
      final wrong = (await c.study.searchMistakes()).first;
      container.read(routerProvider).go('/mistakes/${wrong.id}');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('合上解析重做'));
      await tester.tap(find.text('合上解析重做'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 && find.byKey(const Key('quiz-answer-0')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.textContaining('平方项为零时'),
        findsNothing,
        reason: 'Reference hidden before submit',
      );
      await tester.enterText(
        find.byKey(const Key('quiz-answer-0')),
        '配方得到 (x-3)^2-4，顶点是 (3,-4)。',
      );
      await tester.ensureVisible(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 100 && find.text('独立做对了').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.text('独立做对了'));
      await tester.tap(find.text('独立做对了'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 100 && find.text('讲解与变式训练').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture('redo-feedback-desktop');
      await tester.ensureVisible(find.text('讲解与变式训练'));
      await tester.tap(find.text('讲解与变式训练'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      for (
        var i = 0;
        i < 200 && (c.busy || find.byType(QuestionCard).evaluate().isEmpty);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(c.busy, false);
      expect(c.messages.last.status, 'complete');
      expect(find.byType(QuestionCard), findsOneWidget);
      final quiz = (await c.practice.list(messageId: c.messages.last.id))
          .single;
      await tester.ensureVisible(find.byKey(const Key('option-B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('option-B')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-quiz')));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 &&
            (await c.practice.detail(quiz.id)).latest!.status != 'graded';
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect((await c.practice.detail(quiz.id)).latest!.correct, false);
      expect(
        (await c.db.select(c.db.practiceAttempts).get())
            .where((a) => a.status == 'graded')
            .length,
        2,
      );
      await capture('chat-quiz-desktop');
      if (Platform.isLinux) {
        final windows = await Process.run('xdotool', [
          'search',
          '--onlyvisible',
          '--class',
          'org.tixun.tixun',
        ]);
        final id = windows.stdout.toString().trim().split('\n').first;
        await Process.run('xdotool', ['windowsize', id, '390', '844']);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(QuestionCard));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await capture('chat-quiz-phone');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.shutdown();
    },
  );
}
