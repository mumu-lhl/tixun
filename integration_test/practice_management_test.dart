import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/features/practice/question_spec.dart';

import 'support/gui_capture.dart';

Future<void> until(WidgetTester t, bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), true);
  await t.pumpAndSettle();
}

Future<void> click(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Offline mini quiz resumes drafts, saves distinct grading, edits a version and restores trash on a phone',
    (t) async {
      final root = await Directory.systemTemp.createTemp('tixun-manage-gui');
      final c = await AppController.openRoot(root, demo: true, seed: false);
      final numeric = await c.practice.create(
        const QuestionSpec(
          kind: 'numeric',
          stem: r'解方程 $3x+5=20$，填写 $x$。',
          answers: [
            ['5'],
          ],
          explanation: r'$3x=15$，所以 $x=5$。',
          timeLimitSeconds: 60,
        ),
      );
      await c.practice.create(
        const QuestionSpec(
          kind: 'multiple_choice',
          stem: '选出偶数。',
          options: {'A': '2', 'B': '3', 'C': '4'},
          answers: [
            ['A'],
            ['C'],
          ],
        ),
      );
      await c.practice.create(
        const QuestionSpec(
          kind: 'short_answer',
          stem: '用自己的话解释什么是独立作答。',
          answers: [
            ['不看解析完成解题并检查推导。'],
          ],
        ),
      );
      await c.study.saveKnowledge(
        const KnowledgeDraft(title: '配方与顶点', content: '通过完全平方得到顶点。'),
      );
      await c.study.saveKnowledge(
        const KnowledgeDraft(title: '奇偶性', content: '整数除以 2 的余数。'),
      );
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      scope.read(routerProvider).go('/practice');
      await t.pumpAndSettle();
      await click(t, find.byKey(const Key('random-practice')));
      for (var i = 0; i < 3; i++) {
        final run = (await c.practice.loadRun())!;
        final detail = await c.practice.detail(
          run.ids[run.index],
          attemptId: run.attempts[run.index],
        );
        await until(
          t,
          () =>
              find.byKey(Key('quiz-${detail.row.id}')).evaluate().isNotEmpty &&
              find.byKey(const Key('submit-quiz')).evaluate().isNotEmpty,
        );
        if (detail.spec.kind == 'multiple_choice') {
          await click(t, find.byKey(const Key('option-A')));
          await click(t, find.byKey(const Key('option-C')));
        } else {
          await t.enterText(
            find.byKey(const Key('quiz-answer-0')),
            detail.spec.kind == 'numeric' ? '5' : '我还需要看解析才能解题。',
          );
          await t.pump();
          if (i == 0) {
            await c.practice.flushDrafts();
            scope.read(routerProvider).go('/practice');
            await t.pumpAndSettle();
            await click(t, find.textContaining('继续小测'));
            await until(
              t,
              () =>
                  find.byKey(const Key('quiz-answer-0')).evaluate().isNotEmpty,
            );
            expect(
              t
                  .widget<TextField>(find.byKey(const Key('quiz-answer-0')))
                  .controller!
                  .text,
              detail.spec.kind == 'numeric' ? '5' : '我还需要看解析才能解题。',
            );
          }
        }
        if (i == 0) await guiCapture('management', 'phone-random-quiz');
        await click(t, find.byKey(const Key('submit-quiz')));
        if (detail.spec.kind == 'short_answer') {
          await until(t, () => find.text('还需要练习').evaluate().isNotEmpty);
          await click(t, find.text('还需要练习'));
        }
        await until(
          t,
          () =>
              find.text('本次作答正确').evaluate().isNotEmpty ||
              find.text('本次作答需要订正').evaluate().isNotEmpty,
        );
        expect(
          find.text('再做一次'),
          findsNothing,
          reason: 'A fixed run attempt must not change underneath its run',
        );
        await until(
          t,
          () =>
              t
                  .widget<FilledButton>(
                    find.byKey(const Key('next-run-question')),
                  )
                  .onPressed !=
              null,
        );
        await click(t, find.byKey(const Key('next-run-question')));
      }
      await until(t, () => find.text('已保存 3 次作答').evaluate().isNotEmpty);
      await guiCapture('management', 'phone-quiz-summary');
      expect((await c.practice.loadRun())!.completed, true);
      scope.read(routerProvider).go('/practice');
      await t.pumpAndSettle();
      await until(
        t,
        () => find.byKey(Key('practice-row-$numeric')).evaluate().isNotEmpty,
      );
      final row = find.byKey(Key('practice-row-$numeric'));
      await click(
        t,
        find.descendant(
          of: row,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await click(t, find.text('修订题目与答案'));
      await t.enterText(
        find.byKey(const Key('question-stem')),
        r'修订后的数值检测：$4+3$ 等于多少？',
      );
      await t.enterText(find.byKey(const Key('question-answers')), '7');
      await click(t, find.text('保存题目'));
      await until(
        t,
        () => find.byKey(const Key('quiz-answer-0')).evaluate().isNotEmpty,
      );
      final revised = (await c.practice.list()).firstWhere(
        (q) => q.parentQuestionId == numeric,
      );
      expect((await c.practice.detail(numeric)).spec.answers, [
        ['5'],
      ]);
      await t.enterText(find.byKey(const Key('quiz-answer-0')), '7');
      await click(t, find.byKey(const Key('submit-quiz')));
      await until(t, () => find.text('本次作答正确').evaluate().isNotEmpty);
      await click(t, find.text('查看全部作答历史'));
      await until(t, () => find.text('作答正确').evaluate().isNotEmpty);
      await guiCapture('management', 'phone-attempt-history');
      await click(t, find.text('作答正确'));
      await until(
        t,
        () =>
            find.byKey(Key('quiz-${revised.id}')).evaluate().isNotEmpty &&
            find.text('本次作答正确').evaluate().isNotEmpty,
      );
      expect(find.text('再做一次'), findsNothing);
      scope.read(routerProvider).go('/practice');
      await t.pumpAndSettle();
      await until(
        t,
        () =>
            find.byKey(Key('practice-row-${revised.id}')).evaluate().isNotEmpty,
      );
      await click(
        t,
        find.descendant(
          of: find.byKey(Key('practice-row-${revised.id}')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await click(t, find.text('移入回收区'));
      await click(t, find.byTooltip('练习回收区'));
      await until(
        t,
        () =>
            find.byKey(Key('practice-row-${revised.id}')).evaluate().isNotEmpty,
      );
      await click(
        t,
        find.descendant(
          of: find.byKey(Key('practice-row-${revised.id}')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await click(t, find.text('恢复题目'));
      await until(
        t,
        () => find.byKey(Key('practice-row-${revised.id}')).evaluate().isEmpty,
      );
      expect((await c.practice.detail(revised.id)).latest!.correct, true);
      scope.read(routerProvider).go('/knowledge');
      await t.pumpAndSettle();
      await until(t, () => find.text('配方与顶点').evaluate().isNotEmpty);
      await click(t, find.byTooltip('选择多条资料'));
      await click(t, find.text('全选已加载'));
      await guiCapture('management', 'phone-batch-notes');
      await click(t, find.text('移入回收区'));
      await until(t, () => find.text('撤销').evaluate().isNotEmpty);
      await click(t, find.text('撤销'));
      await until(t, () => find.text('配方与顶点').evaluate().isNotEmpty);
      expect((await c.study.searchKnowledge()).length, 2);
      await c.theme(ThemeMode.dark);
      await t.pumpAndSettle();
      await guiCapture('management', 'phone-knowledge-dark');
      await resizeGui(t, 1280, 900);
      await guiCapture('management', 'desktop-knowledge-dark');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await c.shutdown();
      if (await root.exists()) await root.delete(recursive: true);
    },
  );
}
