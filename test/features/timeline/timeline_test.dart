import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/timeline/timeline_screen.dart";
import "package:tixun/features/timeline/timeline_store.dart";

void main() {
  test("countdown handles future dates, a date range and the past", () {
    final start = DateTime(2027, 3, 10);
    final end = DateTime(2027, 3, 12);
    expect(timelineStatus(start, end, DateTime(2027, 3, 3, 23)), (
      phase: TimelinePhase.upcoming,
      days: 7,
    ));
    expect(timelineStatus(start, end, start), (
      phase: TimelinePhase.inProgress,
      days: 2,
    ));
    expect(timelineStatus(start, end, end), (
      phase: TimelinePhase.endsToday,
      days: 0,
    ));
    expect(timelineStatus(start, end, DateTime(2027, 3, 15)), (
      phase: TimelinePhase.past,
      days: 3,
    ));
    expect(timelineStatus(start, null, start), (
      phase: TimelinePhase.today,
      days: 0,
    ));
  });

  test(
    "timeline stores date ranges and notes and supports editing and deletion",
    () async {
      final db = AppDatabase.memory();
      final store = TimelineStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final id = await store.save(
        title: "  二模  ",
        start: DateTime(2027, 3, 10),
        end: DateTime(2027, 3, 12),
        notes: "带准考证",
      );
      var event = (await store.watchEvents().first).single;
      expect(event.title, "二模");
      expect(event.notes, "带准考证");
      expect(event.startDate.toUtc(), DateTime.utc(2027, 3, 10));
      expect(event.endDate!.toUtc(), DateTime.utc(2027, 3, 12));
      await store.save(id: id, title: "二模调整", start: DateTime(2027, 3, 11));
      event = (await store.watchEvents().first).single;
      expect(event.title, "二模调整");
      expect(event.endDate, isNull);
      expect(event.notes, isEmpty);
      await store.delete(id);
      expect(await store.watchEvents().first, isEmpty);
    },
  );

  testWidgets("calendar and list show an event, its notes and countdown", (
    tester,
  ) async {
    late AppController controller;
    late Directory root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp("timeline-test");
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );
      await controller.initialize(seed: false);
      final today = DateUtils.dateOnly(DateTime.now());
      await controller.timeline.save(
        title: "期中考",
        start: today,
        end: DateTime(today.year, today.month, today.day + 2),
        notes: "带笔和准考证",
      );
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(() async {
        await controller.db.close();
        await root.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TimelineScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("期中考"), findsOneWidget);
    expect(find.text("带笔和准考证"), findsOneWidget);
    expect(find.text("进行中 · 还有 2 天结束"), findsOneWidget);
    await tester.tap(find.text("列表"));
    await tester.pumpAndSettle();
    expect(find.text("期中考"), findsOneWidget);
    expect(find.text("带笔和准考证"), findsOneWidget);
    await tester.tap(find.byKey(const Key("timeline-add")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key("timeline-name")), "二模");
    await tester.enterText(find.byKey(const Key("timeline-notes")), "提前到场");
    await tester.ensureVisible(find.byKey(const Key("timeline-save")));
    await tester.tap(find.byKey(const Key("timeline-save")));
    await tester.pumpAndSettle();
    late List<TimelineEvent> saved;
    await tester.runAsync(() async {
      saved = await controller.db.select(controller.db.timelineEvents).get();
    });
    expect(saved.map((e) => e.title), contains("二模"));
    expect(saved.singleWhere((e) => e.title == "二模").notes, "提前到场");
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
  });
}
