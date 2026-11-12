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
  for (var i = 0; i < 150 && !f(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(f(), true);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Configured subjects drive dropdowns and custom subjects; compact settings and chat preserve real behavior',
    (t) async {
      final c = await AppController.open(demo: true);
      await c.setLearningSubjects(['语文', '数学', '英语']);
      await c.study.saveKnowledge(
        const KnowledgeDraft(
          title: '物理受力分析的步骤',
          content: '先选研究对象，再画受力图。',
          subject: '物理',
        ),
      );
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      await resizeGui(t, 390, 844);
      scope.read(routerProvider).go('/settings');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('subject-switch')), findsNothing);
      await click(t, find.byKey(const Key('settings-subjects')));
      for (final name in ['物理', '化学', '生物']) {
        await click(t, find.byKey(ValueKey('study-subject-$name')));
      }
      await t.enterText(find.byKey(const Key('custom-subject')), '日语');
      await click(t, find.widgetWithText(OutlinedButton, '添加科目'));
      await guiCapture('subjects', 'selection-phone');
      await click(t, find.byKey(const Key('save-subjects')));
      await ready(
        t,
        () => find.byKey(const Key('settings-ai')).evaluate().isNotEmpty,
      );
      expect(c.learningSubjects, ['语文', '数学', '英语', '物理', '化学', '生物', '日语']);
      await guiCapture('subjects', 'settings-phone');
      await c.newSession();
      await c.setSessionSubject(c.selected!, '数学');
      await c.renameSession(c.selected!, '数学 · 导数与函数单调性的一次完整复盘');
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('chat-input')), '请解释函数的单调性');
      await t.pump(); // Rebuild the input-driven Send button before tapping.
      await click(t, find.byKey(const Key('send-message')));
      await ready(t, () => !c.busy && c.messages.length == 2);
      await guiCapture('subjects', 'chat-phone');
      // The subject switch lives on the home page now, not in chat:
      // open it from /study, where the menu lists the configured subjects.
      scope.read(routerProvider).go('/study');
      await t.pumpAndSettle();
      await click(t, find.byKey(const Key('subject-switch')));
      await t.pumpAndSettle();
      await guiCapture('subjects', 'subject-menu-phone');
      final menuItems = find.byType(MenuItemButton);
      for (final hidden in ['地理', '历史', '政治']) {
        expect(
          find.descendant(of: menuItems, matching: find.text(hidden)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: menuItems, matching: find.text('日语')),
        findsWidgets,
      );
      await click(
        t,
        find.descendant(of: menuItems, matching: find.text('物理')).last,
      );
      // Switching on the home page changes the filter only; the chat
      // session keeps its own subject (it used to follow the switch when
      // the switch lived in chat).
      await ready(
        t,
        () => c.subjectFilter == '物理' && c.selected?.subject == '数学',
      );
      final mathSessionId = c.selected!.id;
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await click(t, find.byTooltip('会话列表'));
      expect(find.byKey(const Key('session-show-all')), findsOneWidget);
      await guiCapture('subjects', 'sessions-filtered-phone');
      await click(t, find.byKey(const Key('session-show-all')));
      expect(c.sessions.map((s) => s.id), contains(mathSessionId));
      await guiCapture('subjects', 'sessions-all-phone');
      await click(t, find.widgetWithText(ListTile, '数学 · 导数与函数单调性的一次完整复盘'));
      expect(c.selected!.id, mathSessionId);
      expect(c.messages.length, 2);
      await c.setSubjectFilter('物理');
      scope.read(routerProvider).go('/knowledge');
      await t.pumpAndSettle();
      await ready(t, () => find.text('物理受力分析的步骤').evaluate().isNotEmpty);
      final search = find.byType(TextField).first;
      await t.enterText(search, '没有匹配的关键词');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await ready(
        t,
        () => find
            .byKey(const Key('clear-library-filters'))
            .evaluate()
            .isNotEmpty,
      );
      await guiCapture('subjects', 'filtered-empty-phone');
      await click(t, find.byKey(const Key('clear-library-filters')));
      await ready(
        t,
        () =>
            c.subjectFilter == '' &&
            find.text('物理受力分析的步骤').evaluate().isNotEmpty,
      );
      await resizeGui(t, 1280, 900);
      await c.setLanguage('en');
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/settings');
      await t.pumpAndSettle();
      await guiCapture('subjects', 'settings-desktop-english');
      scope.read(routerProvider).go('/mistakes');
      await t.pumpAndSettle();
      await guiCapture('subjects', 'mistakes-desktop-english');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      scope.dispose();
      await c.shutdown();
    },
  );
}
