import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

Future<(AppController, GoRouter)> openApp(
  WidgetTester tester, {
  double width = 390,
  String route = '/chat',
}) async {
  late Directory root;
  late AppController c;
  await tester.runAsync(() async {
    root = await Directory.systemTemp.createTemp('chat-settings-back');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    await c.initialize(seed: false);
    await c.newSession();
  });
  final scope = ProviderContainer(
    overrides: [appControllerProvider.overrideWith((_) => c)],
  );
  addTearDown(() async {
    scope.dispose();
    await c.db.close();
    await root.delete(recursive: true);
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: scope, child: const TixunApp()),
  );
  final router = scope.read(routerProvider);
  router.go(route);
  await tester.pumpAndSettle();
  return (c, router);
}

Future<void> openFromChat(
  WidgetTester tester,
  String destination, {
  double width = 390,
}) async {
  if (destination == 'ai') {
    if (width < 700) {
      await tester.tap(find.byKey(const Key('chat-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模型设置'));
    } else {
      await tester.tap(find.byTooltip('模型设置'));
    }
  } else {
    await tester.tap(find.byKey(const Key('reasoning-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理提示词'));
  }
  await tester.pumpAndSettle();
}

Future<void> pageBack(WidgetTester tester, String destination) async {
  final button = destination == 'ai'
      ? find.byType(BackButton)
      : find.byKey(const Key('prompt-manager-back'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  // Pairwise coverage: both layouts × destinations, both destinations ×
  // back methods, and both layouts × back methods. Nested/deep-link/editor
  // regressions below remain independent.
  for (final (width, destination, systemBack) in [
    (390.0, 'ai', false),
    (1200.0, 'ai', true),
    (390.0, 'prompts', true),
    (1200.0, 'prompts', false),
  ]) {
    testWidgets(
      'chat → $destination → ${systemBack ? 'system' : 'page'} back at $width',
      (tester) async {
        final (c, router) = await openApp(tester, width: width);
        final sessionId = c.selected!.id;
        await openFromChat(tester, destination, width: width);
        expect(router.state.uri.path, '/settings/$destination');
        if (systemBack) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await pageBack(tester, destination);
        }
        expect(router.state.uri.path, '/chat');
        expect(find.byKey(const Key('chat-input')), findsOneWidget);
        expect(c.selected!.id, sessionId);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final destination in ['ai', 'prompts']) {
    for (final deepLink in [false, true]) {
      testWidgets(
        '$destination entered from ${deepLink ? 'deep link' : 'settings'} returns to settings',
        (tester) async {
          final (_, router) = await openApp(
            tester,
            route: deepLink ? '/settings/$destination' : '/settings',
          );
          if (!deepLink) {
            router.push('/settings/$destination');
            await tester.pumpAndSettle();
          }
          await pageBack(tester, destination);
          expect(router.state.uri.path, '/settings');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final systemBack in [false, true]) {
    testWidgets(
      'nested ChatGPT ${systemBack ? 'system' : 'page'} back retains chat origin',
      (tester) async {
        final (_, router) = await openApp(tester);
        await openFromChat(tester, 'ai');
        final subscription = find.widgetWithText(ListTile, 'ChatGPT 订阅');
        await tester.ensureVisible(subscription);
        await tester.tap(subscription);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/settings/chatgpt');
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('返回'));
        }
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/settings/ai');
        await pageBack(tester, 'ai');
        expect(router.state.uri.path, '/chat');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in ['clean', 'discard', 'save']) {
    testWidgets('prompt editor $action preserves manager and chat origin', (
      tester,
    ) async {
      final (c, router) = await openApp(tester);
      await openFromChat(tester, 'prompts');
      final prompt = find.byKey(const Key('prompt-global'));
      await tester.ensureVisible(prompt);
      await tester.tap(prompt);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/settings/prompts/global');
      final original = c.prompts.text('global');
      if (action != 'clean') {
        await tester.enterText(
          find.byKey(const Key('prompt-content')),
          '临时导航测试提示词',
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      if (action != 'clean') {
        expect(find.text('提示词尚未保存'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/settings/prompts/global');
        await tester.tap(find.byKey(const Key('prompt-back')));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.text(action == 'save' ? '保存提示词' : '放弃修改').last),
        );
        await tester.pumpAndSettle();
      }
      expect(router.state.uri.path, '/settings/prompts');
      expect(
        c.prompts.text('global'),
        action == 'save' ? '临时导航测试提示词' : original,
      );
      await pageBack(tester, 'prompts');
      expect(router.state.uri.path, '/chat');
      expect(tester.takeException(), isNull);
    });
  }
}
