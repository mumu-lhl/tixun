import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tixun/features/exams/exam_calendar.dart';
import 'package:tixun/features/chat/session_list.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

void main() {
  late AppController c;
  late ProviderContainer scope;
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('tixun-navigation');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(dir),
      MemoryKeyStore(),
      MockChatProvider(),
      demo: true,
    );
    await c.initialize();
    scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
  });
  tearDown(() async {
    scope.dispose();
    await c.shutdown();
    if (await c.files.root.exists()) await c.files.root.delete(recursive: true);
  });

  testWidgets('Session list exposes hidden conversations by clearing filters', (
    t,
  ) async {
    await c.setSubjectFilter('物理');
    await c.searchSessions('受力');
    expect(c.sessions.length, lessThan(c.allSessions.length));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SessionList()),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('session-show-all')));
    await t.pumpAndSettle();
    expect(c.subjectFilter, isEmpty);
    expect(c.search, isEmpty);
    expect(c.sessions.length, c.allSessions.length);
    expect(find.text('二次函数：从配方理解顶点'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets('exam calendar can return after push and a direct route', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        GoRoute(
          path: '/study',
          builder: (_, _) => const Scaffold(body: Text('Study home')),
        ),
        GoRoute(
          path: '/exams',
          builder: (_, _) => const Scaffold(body: ExamCalendarScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    router.push('/exams');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('exam-calendar-back')), findsOneWidget);
    await t.tap(find.byKey(const Key('exam-calendar-back')));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/study');
    router.go('/exams');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('exam-calendar-back')));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/study');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
