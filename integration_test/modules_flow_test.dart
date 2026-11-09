import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/library/study_store.dart';

import 'support/gui_capture.dart';

Future<void> click(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> ready(WidgetTester t, bool Function() f) async {
  for (var i = 0; i < 120 && !f(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(f(), true);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Shared subject directory: create hierarchy, classify notes and mistakes, filter and prepare targeted practice',
    (t) async {
      final c = await AppController.open(demo: true);
      final note = await c.study.saveKnowledge(
        const KnowledgeDraft(
          title: '函数单调性的判断方法',
          content: '先确定定义域，再使用导数或定义法判断单调区间。',
        ),
      );
      final mistake = await c.study.saveMistake(
        const MistakeDraft(
          title: '参数取值与函数单调性的综合题',
          question: '已知函数 f(x)=x²+ax，求其在区间 [1,2] 上单调递增时参数 a 的取值范围。',
        ),
      );
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/knowledge');
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      await click(t, find.text('管理目录'));
      await click(t, find.byKey(const Key('module-add-root')));
      await t.enterText(find.byType(TextField).last, '函数与导数');
      await click(t, find.widgetWithText(FilledButton, '保存'));
      await ready(t, () => find.text('函数与导数').evaluate().isNotEmpty);
      final root = (await c.study.modules.list('数学')).single;
      await click(t, find.byKey(ValueKey('module-menu-${root.id}')));
      await click(t, find.text('新增子模块'));
      await t.enterText(find.byType(TextField).last, '单调性与最值');
      await click(t, find.widgetWithText(FilledButton, '保存'));
      await ready(t, () => find.text('单调性与最值').evaluate().isNotEmpty);
      final child = (await c.study.modules.list('数学'))
          .firstWhere((m) => m.parentId == root.id);
      await guiCapture('modules', 'directory-phone');
      await click(t, find.byType(BackButton));
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/knowledge/${note.id}');
      await t.pumpAndSettle();
      await ready(
        t,
        () => find.byKey(const Key('assign-modules')).evaluate().isNotEmpty,
      );
      await click(t, find.byKey(const Key('assign-modules')));
      await click(t, find.widgetWithText(CheckboxListTile, '单调性与最值'));
      await click(t, find.widgetWithText(FilledButton, '保存'));
      await ready(
        t,
        () => find
            .widgetWithText(ActionChip, '函数与导数 / 单调性与最值')
            .evaluate()
            .isNotEmpty,
      );
      expect(await c.study.modules.ids(note.id, false), [child.id]);
      await click(t, find.widgetWithText(ActionChip, '函数与导数 / 单调性与最值'));
      await ready(t, () => find.text('函数单调性的判断方法').evaluate().isNotEmpty);
      await guiCapture('modules', 'filtered-knowledge-phone');
      await click(t, find.text('本模块专项训练'));
      await ready(
        t,
        () =>
            c.selected?.mode == 'exam' &&
            (c.selected?.draft.contains('先确定定义域') ?? false),
      );
      expect(c.messages, isEmpty);
      expect(await c.db.select(c.db.studyChatLinks).get(), isNotEmpty);
      scope.read(routerProvider).go('/mistakes/${mistake.id}');
      await t.pumpAndSettle();
      await ready(
        t,
        () => find.byKey(const Key('assign-modules')).evaluate().isNotEmpty,
      );
      await click(t, find.byKey(const Key('assign-modules')));
      await click(t, find.widgetWithText(CheckboxListTile, '单调性与最值'));
      await click(t, find.widgetWithText(FilledButton, '保存'));
      await ready(
        t,
        () => find
            .widgetWithText(ActionChip, '函数与导数 / 单调性与最值')
            .evaluate()
            .isNotEmpty,
      );
      expect(await c.study.modules.ids(mistake.id, true), [child.id]);
      await resizeGui(t, 1280, 900);
      await c.setLanguage('en');
      await t.pumpAndSettle();
      await guiCapture('modules', 'mistake-desktop-english');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      scope.dispose();
      await c.shutdown();
    },
  );
}
