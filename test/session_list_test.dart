import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/theme.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/app_strings.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/chat/session_list.dart';

void main() {
  testWidgets('History groups by recency and stays flat while searching', (
    tester,
  ) async {
    late AppController c;
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('tixun-session-list');
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      await c.initialize();
      final now = DateTime.now();
      Future<void> seed(String title, Duration ago) async {
        final s = await c.db.createSession(title: title);
        await (c.db.update(c.db.chatSessions)..where((t) => t.id.equals(s.id)))
            .write(ChatSessionsCompanion(updatedAt: Value(now.subtract(ago))));
      }

      await seed('今天的对话', Duration.zero);
      await seed('昨天的对话', const Duration(days: 1));
      await seed('三天前的对话', const Duration(days: 3));
      await seed('十天前的对话', const Duration(days: 10));
      await c.reload();
    });
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    addTearDown(() async {
      container.dispose();
      await c.db.close();
      await dir.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('zh'),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(
            body: SizedBox(height: 800, child: SessionList()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('最近 7 天'), findsOneWidget);
    expect(find.text('更早'), findsOneWidget);
    // Groups stay newest-first, matching the sessions order.
    final todayY = tester.getTopLeft(find.text('今天')).dy;
    final yesterdayY = tester.getTopLeft(find.text('昨天')).dy;
    final last7DaysY = tester.getTopLeft(find.text('最近 7 天')).dy;
    final earlierY = tester.getTopLeft(find.text('更早')).dy;
    expect(todayY, lessThan(yesterdayY));
    expect(yesterdayY, lessThan(last7DaysY));
    expect(last7DaysY, lessThan(earlierY));
    for (final title in ['今天的对话', '昨天的对话', '三天前的对话', '十天前的对话']) {
      expect(find.text(title), findsOneWidget);
    }
    // A search ranks title matches first, so no group headers are shown.
    await tester.runAsync(() => c.searchSessions('三天前'));
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsNothing);
    expect(find.text('最近 7 天'), findsNothing);
    expect(find.text('三天前的对话'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Empty history shows an icon and guidance', (tester) async {
    late AppController c;
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('tixun-session-list-empty');
      c = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      await c.initialize();
    });
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    addTearDown(() async {
      container.dispose();
      await c.db.close();
      await dir.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('zh'),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(
            body: SizedBox(height: 800, child: SessionList()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.textContaining('还没有对话'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
