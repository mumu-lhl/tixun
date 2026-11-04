import 'support/gui_capture.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/practice/question_card.dart';

Future<void> capture(String name) => guiCapture('practice', name);

Future<void> ready(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
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
        final messages = find.byKey(
          PageStorageKey('messages-${c.selected!.id}'),
        );
        await tester.scrollUntilVisible(
          find.byType(QuestionCard),
          300,
          scrollable: find
              .descendant(of: messages, matching: find.byType(Scrollable))
              .first,
          maxScrolls: 30,
        );
        await ready(tester, find.byType(QuestionCard));
        await tester.ensureVisible(find.byType(QuestionCard));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await capture('chat-quiz-phone');
      }
      // Due tasks and diagnostics consume the same persisted attempts.
      final schedule = (await c.review.forQuestion(quiz.id))!;
      await c.review.adjust(schedule.id, dueAt: DateTime.now());
      container.read(routerProvider).go('/study');
      await tester.pumpAndSettle();
      expect(await c.review.dueCount(), 1);
      await ready(tester, find.byKey(const Key('today-review')));
      await capture('daily-learning-phone');
      await tester.ensureVisible(find.byKey(const Key('today-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-review')));
      await tester.pumpAndSettle();
      await ready(tester, find.text('开始复习'));
      await capture('review-phone');
      await tester.tap(find.text('开始复习'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 && find.byKey(const Key('option-A')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.byKey(const Key('option-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('option-A')));
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
      expect(
        (await c.review.forQuestion(quiz.id))!.repetitions,
        0,
        reason: 'Unverified AI answer never advances independent mastery',
      );
      expect(await c.review.dueCount(), 0);
      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      await ready(tester, find.text('学习诊断'));
      await capture('progress-phone');
      await c.theme(ThemeMode.dark);
      await tester.pumpAndSettle();
      await capture('progress-dark-phone');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await c.shutdown();
    },
  );
}
