import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await c.shutdown();
    await root.delete(recursive: true);
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
