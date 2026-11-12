import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/study_tools.dart';
import 'package:go_router/go_router.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/features/chat/chat_screen.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  late AppController c;
  late Directory root;
  late ProviderContainer scope;
  late GoRouter router;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat-fullscreen');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    await c.newSession();
    router = GoRouter(
      initialLocation: '/knowledge',
      routes: [
        ShellRoute(
          builder: (ctx, state, child) =>
              AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/study', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/knowledge', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
          ],
        ),
      ],
    );
    scope = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((ref) => c),
        routerProvider.overrideWithValue(router),
      ],
    );
  });
  tearDown(() async {
    scope.dispose();
    router.dispose();
    c.dispose();
    await c.db.close();
    await root.delete(recursive: true);
  });
  testWidgets('Material tools support individual categories and all-on/off', (
    t,
  ) async {
    router.go('/chat');
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('开启本会话资料工具'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('study-tools-knowledge')));
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(c.studyToolCategories, {StudyToolCategory.knowledge});
    expect(c.selected!.toolsEnabled, isTrue);
    await t.tap(find.byTooltip('管理本会话资料工具'));
    await t.pumpAndSettle();
    await t.tap(find.text('全部启用'));
    await t.pumpAndSettle();
    expect(c.studyToolCategories, allStudyToolCategories);
    await t.tap(find.byTooltip('管理本会话资料工具'));
    await t.pumpAndSettle();
    await t.tap(find.text('关闭全部'));
    await t.pumpAndSettle();
    expect(c.selected!.toolsEnabled, isFalse);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets('Externally sent drafts clear without losing new typing', (
    t,
  ) async {
    await c.draft('整理这份知识');
    router.go('/chat');
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    final input = find.byKey(const Key('chat-input'));
    expect(t.widget<TextField>(input).controller!.text, '整理这份知识');
    await t.runAsync(() => c.send('整理这份知识'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(input).controller!.text, isEmpty);
    await t.enterText(input, '第二个问题');
    late Future<void> pending;
    await t.runAsync(() async {
      pending = c.send('第二个问题');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pump();
    await t.enterText(input, '还没发出的新问题');
    await t.runAsync(() => pending);
    await t.pumpAndSettle();
    expect(t.widget<TextField>(input).controller!.text, '还没发出的新问题');
    expect(c.selected!.draft, '还没发出的新问题');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets('Return-to-bottom appears only when reading history at rest', (
    t,
  ) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final session = c.selected!;
    for (var i = 0; i < 35; i++) {
      await c.db
          .into(c.db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'history-$i',
              sessionId: session.id,
              role: i.isEven ? 'user' : 'assistant',
              content: '第 $i 条学习记录。\n解释知识与独立尝试。\n记录这一轮的学习结果。',
              createdAt: DateTime(2026, 11, 12, 10, i),
            ),
          );
    }
    await c.selectSession(session);
    router.go('/chat');
    await t.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    await t.pumpAndSettle();
    final bottom = find.byKey(const Key('chat-scroll-bottom'));
    final messages = find.byKey(PageStorageKey('messages-${session.id}'));
    expect(bottom, findsNothing);
    final drag = await t.startGesture(t.getCenter(messages));
    await drag.moveBy(const Offset(0, 20));
    await t.pump();
    await drag.moveBy(const Offset(0, 280));
    await t.pump();
    expect(
      bottom,
      findsNothing,
      reason: 'The shortcut must not cover an active scroll',
    );
    await drag.up();
    await t.pumpAndSettle();
    expect(bottom, findsOneWidget);
    await t.tap(bottom);
    await t.pumpAndSettle();
    expect(bottom, findsNothing);
    expect(find.textContaining('第 34 条学习记录。'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('chat-input')),
      '长问题第一行\n第二行\n第三行\n第四行',
    );
    await t.pumpAndSettle();
    expect(find.textContaining('第 34 条学习记录。').hitTestable(), findsOneWidget);
    expect(bottom, findsNothing);
    t.view.physicalSize = const Size(1280, 900);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets(
    'Phone Chat fills the screen and returns to its originating tab',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await t.tap(find.byKey(const Key('nav-1')));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        t.getRect(find.byKey(const Key('chat-input'))).bottom,
        greaterThan(770),
      );
      await t.tap(find.byKey(const Key('chat-back')));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/knowledge');
      router.go('/chat');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('chat-back')));
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/study');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
}
