import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

import 'support/gui_capture.dart';

import 'dart:io';

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
      final photo = await c.exams.addImage(
        subject.id,
        'paper',
        File('assets/demo/two_problems.png').absolute.path,
      );
      final photoMenu = find.byKey(Key('exam-image-menu-${photo.id}'));
      await ready(t, () => photoMenu.evaluate().isNotEmpty);
      await click(t, find.byKey(Key('exam-image-preview-${photo.id}')));
      await click(t, find.byTooltip('关闭预览'));
      await click(t, photoMenu);
      expect(find.text('查看保留的原图'), findsNothing);
      await click(t, find.text('裁剪 / 旋转 / 缩小'));
      await ready(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty,
      );
      final canvas = t.getRect(find.byKey(const Key('crop-canvas')));
      final crop = await t.startGesture(
        canvas.topLeft + Offset(canvas.width * .05, canvas.height * .1),
      );
      await crop.moveTo(
        canvas.topLeft + Offset(canvas.width * .95, canvas.height * .8),
      );
      await crop.up();
      await t.pumpAndSettle();
      await click(t, find.text('保存图片编辑'));
      await ready(
        t,
        () => find.byKey(const Key('crop-canvas')).evaluate().isEmpty,
      );
      final edited = (await c.db.select(c.db.examAttachments).get()).single;
      expect(edited.originalPath, photo.relativePath);
      await click(t, photoMenu);
      expect(find.text('查看保留的原图'), findsOneWidget);
      await guiCapture('exams', 'photo-menu-phone');
      await click(t, find.text('查看保留的原图'));
      expect(find.text('保留的原图'), findsOneWidget);
      await click(t, find.byTooltip('关闭预览'));
      await click(t, photoMenu);
      await click(t, find.text('删除图片'));
      await click(t, find.text('取消'));
      expect(await c.db.select(c.db.examAttachments).get(), hasLength(1));
      await guiCapture('exams', 'photo-thumbnail-phone');
      await click(t, photoMenu);
      await click(t, find.text('删除图片'));
      await click(t, find.widgetWithText(FilledButton, '删除'));
      await ready(t, () => photoMenu.evaluate().isEmpty);
      expect(await c.db.select(c.db.examAttachments).get(), isEmpty);
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
      await c.exams.saveEvent(title: '上学期月考', date: DateTime(2025, 9, 12));
      for (var i = 0; i < 15; i++) {
        await c.exams.saveEvent(
          title: '历史月考 ${i + 1}',
          date: DateTime(2024, i + 1, 10),
        );
      }
      scope.read(routerProvider).go('/exams');
      await t.pumpAndSettle();
      await click(t, find.text('列表'));
      await ready(t, () => find.text('上学期月考').evaluate().isNotEmpty);
      expect(
        t.getTopLeft(find.text('高三上学期期中考试 · 联考成绩记录')).dy,
        lessThan(t.getTopLeft(find.text('上学期月考')).dy),
      );
      await guiCapture('exams', 'timeline-phone');
      await t.drag(
        find.byKey(const PageStorageKey('exam-timeline')),
        const Offset(0, -600),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('exam-calendar-back')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exam-add')).hitTestable(), findsOneWidget);
      await click(t, find.byKey(const Key('exam-add')));
      expect(find.byKey(const Key('exam-record-date')), findsOneWidget);
      await click(t, find.text('取消'));
      await click(t, find.text('日历'));
      expect(find.text('上学期月考'), findsNothing);
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
