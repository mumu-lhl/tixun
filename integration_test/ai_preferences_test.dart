import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';

import 'support/gui_capture.dart';

Future<void> ready(WidgetTester t, bool Function() condition) async {
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
    'Prompt manager edits, previews, restores and persists preferences; per-session reasoning leaves defaults intact',
    (t) async {
      final c = await AppController.open(demo: true);
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      scope.read(routerProvider).go('/settings');
      await t.pumpAndSettle();
      await click(t, find.text('提示词管理'));
      await click(t, find.byKey(const Key('prompt-guided')));
      await t.enterText(
        find.byKey(const Key('prompt-content')),
        '每次只问我一个问题，先听我的尝试。',
      );
      await click(t, find.text('预览效果'));
      expect(find.textContaining('每次只问我一个问题'), findsWidgets);
      await click(t, find.text('关闭'));
      await guiCapture('ai-preferences', 'prompt-editor-desktop');
      await resizeGui(t, 390, 844);
      await guiCapture('ai-preferences', 'prompt-editor-phone');
      await click(t, find.byKey(const Key('save-prompt')));
      await ready(
        t,
        () => find.byKey(const Key('prompt-guided')).evaluate().isNotEmpty,
      );
      expect(c.prompts.text('guided'), '每次只问我一个问题，先听我的尝试。');
      await guiCapture('ai-preferences', 'prompt-list-phone');
      c.config = c.config.copyWith(thinking: true, effort: 'high');
      await c.db.saveConfig(c.config);
      await c.newSession();
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await click(t, find.byKey(const Key('reasoning-menu')));
      await guiCapture('ai-preferences', 'reasoning-phone');
      await click(t, find.byKey(const Key('reasoning-low')));
      await ready(t, () => c.sessionReasoning == 'low');
      expect(c.config.effort, 'high');
      await c.prepareQuickQuiz();
      await t.pumpAndSettle();
      expect(c.sessionReasoning, c.config.effort);
      expect(c.sessionConfig.thinking, true);
      expect(c.config.thinking, true);
      await guiCapture('ai-preferences', 'tool-reasoning-phone');
      await click(t, find.byKey(const Key('reasoning-menu')));
      await click(t, find.text('管理提示词'));
      await click(t, find.byKey(const Key('prompt-guided')));
      await click(t, find.text('恢复默认'));
      await click(t, find.widgetWithText(FilledButton, '恢复默认'));
      await click(t, find.byKey(const Key('save-prompt')));
      await ready(t, () => !c.prompts.overrides.containsKey('guided'));
      scope.read(routerProvider).go('/settings');
      await t.pumpAndSettle();
      await click(t, find.byKey(const ValueKey('language-zh')));
      await click(t, find.text('English').last);
      await ready(t, () => c.languageChoice == 'en');
      expect(find.text('Dynamic colors'), findsOneWidget);
      await click(t, find.byKey(const Key('dynamic-colors')));
      expect(c.dynamicColors, true);
      c.notice = null;
      c.changed();
      ScaffoldMessenger.of(t.element(find.byKey(const Key('dynamic-colors'))))
          .clearSnackBars();
      await t.drag(find.byType(ListView).last, const Offset(0, 900));
      await t.pumpAndSettle();
      await guiCapture('ai-preferences', 'settings-english-phone');
      scope.read(routerProvider).go('/study');
      await t.pumpAndSettle();
      await guiCapture('ai-preferences', 'study-english-phone');
      scope.read(routerProvider).go('/settings/prompts/guided');
      await t.pumpAndSettle();
      expect(find.text('Guided learning'), findsWidgets);
      await guiCapture('ai-preferences', 'prompt-english-phone');
      await resizeGui(t, 1280, 900);
      await c.theme(ThemeMode.dark);
      await t.pumpAndSettle();
      await guiCapture('ai-preferences', 'prompt-english-dark-desktop');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await c.shutdown();
    },
  );
}
