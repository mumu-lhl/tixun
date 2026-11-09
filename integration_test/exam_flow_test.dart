import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

import 'support/gui_capture.dart';

Future<void> click(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> ready(WidgetTester t, bool Function() f) async {
  for (var i = 0; i < 100 && !f(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(f(), true);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Calendar exam creation, subject scores and fast question/subquestion entry persist on phone and desktop',
    (t) async {
      final c = await AppController.open(demo: true);
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/exams');
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      await click(t, find.byKey(const Key('exam-add')));
      await t.enterText(find.byType(TextField).last, '高三上学期期中考试 · 联考成绩记录');
      await click(t, find.widgetWithText(FilledButton, '创建'));
      await ready(t, () => find.text('添加科目').evaluate().isNotEmpty);
      await click(t, find.widgetWithText(FilledButton, '添加科目'));
      expect(find.text('记录赋分'), findsNothing);
      await t.enterText(find.byType(TextField).at(1), '121.5');
      await t.enterText(find.byType(TextField).at(2), '150');
      await click(t, find.widgetWithText(FilledButton, '保存'));
      await ready(
        t,
        () => find.byKey(const Key('exam-edit-scores')).evaluate().isNotEmpty,
      );
      final subject = (await c.db.select(c.db.examSubjects).get()).single;
      expect(subject.rawScore, 121.5);
      expect(subject.scaledScore, isNull);
      await click(t, find.byKey(const Key('exam-edit-scores')));
      await ready(
        t,
        () =>
            find.byKey(const Key('score-next-question')).evaluate().isNotEmpty,
      );
      await click(t, find.byKey(const Key('score-next-question')));
      await t.enterText(find.byType(TextField).at(1), '4');
      await t.enterText(find.byType(TextField).at(2), '5');
      await click(t, find.widgetWithText(TextButton, '下一小题').first);
      expect(find.byType(TextField), findsNWidgets(4));
      await t.enterText(find.byType(TextField).at(2), '3');
      await t.enterText(find.byType(TextField).at(3), '5');
      await guiCapture('exams', 'score-editor-phone');
      await click(t, find.widgetWithText(TextButton, '保存'));
      await t.pumpAndSettle();
      final saved = await (c.db.select(
        c.db.examScoreRows,
      )..where((r) => r.subjectId.equals(subject.id))).get();
      expect(saved, hasLength(2));
      expect(saved.last.earned, 3);
      expect(saved.last.parentId, saved.first.id);
      await guiCapture('exams', 'subject-phone');
      await resizeGui(t, 1280, 900);
      await c.setLanguage('en');
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/exams');
      await t.pumpAndSettle();
      await guiCapture('exams', 'calendar-desktop-english');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      scope.dispose();
      await c.shutdown();
    },
  );
}
