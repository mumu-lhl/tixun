import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/exams/exam_calendar.dart';
import 'package:tixun/features/exams/exam_detail.dart';

Future<AppController> _controller(WidgetTester tester) async {
  late AppController c;
  late Directory root;
  await tester.runAsync(() async {
    root = await Directory.systemTemp.createTemp('tixun-exam-calendar');
    c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
  });
  addTearDown(() async {
    await tester.runAsync(() async {
      await c.db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
  });
  return c;
}

Future<void> _pumpCalendar(WidgetTester tester, AppController c) async {
  final container = ProviderContainer(
    overrides: [appControllerProvider.overrideWith((ref) => c)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ExamCalendarScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

// Unmount the calendar inside the test body: its Drift watch stream
// schedules a zero-duration close timer on unsubscribe, which the
// fake-async zone would otherwise still hold when the test ends.
Future<void> _unmountCalendar(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Moving months keeps the selected day', (tester) async {
    final c = await _controller(tester);
    await _pumpCalendar(tester, c);
    await tester.ensureVisible(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final picked = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
    expect(find.text(picked), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(
      find.text(picked),
      findsOneWidget,
      reason: 'Turning the page must not move the selection to the 1st',
    );
    final next = DateTime(now.year, now.month + 1);
    expect(find.text('${next.year} / ${next.month}'), findsOneWidget);
    await _unmountCalendar(tester);
  });

  testWidgets('Creating an exam with an empty title keeps the dialog open', (
    tester,
  ) async {
    final c = await _controller(tester);
    await _pumpCalendar(tester, c);
    await tester.tap(find.byKey(const Key('exam-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('考试名称需为 1–120 字。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '期中考试');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('考试名称需为 1–120 字。'), findsNothing);
    late List<ExamEvent> events;
    await tester.runAsync(
      () async => events = await c.db.select(c.db.examEvents).get(),
    );
    expect(events.single.title, '期中考试');
    await _unmountCalendar(tester);
  });

  testWidgets('Editing an exam with an empty title keeps the dialog open', (
    tester,
  ) async {
    final c = await _controller(tester);
    late String id;
    await tester.runAsync(() async {
      id = await c.exams.saveEvent(title: '期中', date: DateTime.now());
    });
    late ExamEvent event;
    await tester.runAsync(
      () async => event = await (c.db.select(
        c.db.examEvents,
      )..where((t) => t.id.equals(id))).getSingle(),
    );
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => FilledButton(
                key: const Key('edit-exam'),
                onPressed: () => editExam(ctx, c, event),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-exam')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('考试名称需为 1–120 字。'), findsOneWidget);
    expect(find.text('编辑考试'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '期末');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('编辑考试'), findsNothing);
    late ExamEvent saved;
    await tester.runAsync(
      () async => saved = await (c.db.select(
        c.db.examEvents,
      )..where((t) => t.id.equals(id))).getSingle(),
    );
    expect(saved.title, '期末');
  });
}
