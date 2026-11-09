import 'package:tixun/core/ui/app_menu.dart';
import 'package:tixun/core/ai/ai_options.dart';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chatgpt/responses.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';

import '../test/support/chatgpt_fixture.dart';
import 'support/gui_capture.dart';

Future<void> ready(WidgetTester t, bool Function() condition) async {
  for (var i = 0; i < 150 && !condition(); i++) {
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
    'ChatGPT OAuth fixture signs in, selects account/model, chats and signs out in native GUI',
    (t) async {
      final fixture = ChatGptFixture(), client = Dio();
      client.httpClientAdapter = FixtureAdapter(
        (_) => fixtureSse([
          {'type': 'response.output_text.delta', 'delta': '先找出已知条件，再独立尝试。'},
          completed(),
        ]),
      );
      final dir = await Directory.systemTemp.createTemp('tixun-chatgpt-gui');
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        fixture.keys,
        RoutedChatProvider(fixture.auth, client: client),
      );
      await c.initialize(seed: false);
      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => c)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      scope.read(routerProvider).go('/settings/chatgpt');
      await t.pumpAndSettle();
      await guiCapture('chatgpt', 'sign-in-desktop');
      await click(t, find.byKey(const Key('chatgpt-sign-in')));
      await ready(t, () => find.text('账号已登录').evaluate().isNotEmpty);
      expect(fixture.exchanges, 1);
      await click(t, find.widgetWithText(AppSelectField<String>, '模型'));
      await click(t, find.text('Fixture vision model').last);
      await click(t, find.text('测试连接'));
      await ready(t, () => find.text('连接成功，已收到模型回复。').evaluate().isNotEmpty);
      expect(c.config.kind, 'deepseek');
      await click(t, find.widgetWithText(AppSelectField<String>, '默认思考强度'));
      await click(t, find.text('中').last);
      await click(t, find.byKey(const Key('use-chatgpt')));
      await ready(t, () => c.config.kind == 'chatgpt');
      expect(c.config.vision, true);
      expect(c.config.effort, 'medium');
      expect(AiOptions(c.config).reasoningEfforts, [
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      ]);
      await guiCapture('chatgpt', 'connected-desktop');
      await resizeGui(t, 390, 844);
      await t.drag(find.byType(ListView).last, const Offset(0, 1200));
      await t.pumpAndSettle();
      await guiCapture('chatgpt', 'connected-phone');
      await c.setLanguage('en');
      await t.pumpAndSettle();
      await guiCapture('chatgpt', 'english-phone');
      await c.newSession();
      scope.read(routerProvider).go('/chat');
      await t.pumpAndSettle();
      await click(t, find.byKey(const Key('reasoning-menu')));
      expect(find.byKey(const Key('reasoning-none')), findsNothing);
      expect(find.byKey(const Key('reasoning-xhigh')), findsOneWidget);
      expect(find.byKey(const Key('reasoning-max')), findsOneWidget);
      await guiCapture('chatgpt', 'reasoning-levels-phone');
      await click(t, find.byKey(const Key('reasoning-max')));
      expect(c.sessionConfig.effort, 'max');
      expect(c.config.effort, 'medium');
      await t.enterText(
        find.byKey(const Key('chat-input')),
        'Explain the first step.',
      );
      await t.pump(); // Rebuild the input-driven Send button before tapping.
      await click(t, find.byKey(const Key('send-message')));
      await ready(t, () => !c.busy && c.messages.length == 2);
      expect(c.messages.last.status, 'complete');
      expect(find.textContaining('Using ChatGPT plan'), findsWidgets);
      await guiCapture('chatgpt', 'chat-phone');
      scope.read(routerProvider).go('/settings/chatgpt');
      await t.pumpAndSettle();
      await c.theme(ThemeMode.dark);
      await resizeGui(t, 1280, 900);
      await guiCapture('chatgpt', 'connected-dark-desktop');
      await click(t, find.text('Sign out'));
      await ready(
        t,
        () => find
            .text('Signed out; sign in again to reconnect')
            .evaluate()
            .isNotEmpty,
      );
      expect((await fixture.auth.snapshot()).accounts.single.connected, false);
      scope.read(routerProvider).go('/settings/ai');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('api-key')), findsNothing);
      await click(t, find.text('Restore previous API settings'));
      await ready(t, () => c.config.kind == 'deepseek');
      expect(find.byKey(const Key('api-key')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await c.shutdown();
      await dir.delete(recursive: true);
    },
  );
}
