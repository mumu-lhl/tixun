import "dart:async";
import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/settings/subjects_screen.dart";

class _DelayedSubjectsController extends AppController {
  _DelayedSubjectsController(
    super.db,
    super.files,
    super.keys,
    super.provider, {
    super.demo,
  });

  Completer<void>? saveGate;

  @override
  Future<void> setLearningSubjects(List<String> values) async {
    await saveGate?.future;
    await super.setLearningSubjects(values);
  }
}

void main() {
  testWidgets("custom subject settings can be edited independently", (
    tester,
  ) async {
    const subject = "密集阅读";
    final controller = await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp(
        "tixun-subject-settings",
      );
      final c = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await c.initialize(seed: false);
      await c.setLearningSubjects(["数学", subject]);
      await c.setSubjectFilter(subject);
      return c;
    });
    final c = controller!;
    expect(c.preferences.isLanguageSubject(subject), isFalse);
    final scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => c)],
    );
    addTearDown(() async {
      scope.dispose();
      await c.shutdown();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(
          locale: Locale("en"),
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SubjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final add = find.widgetWithText(OutlinedButton, "Add subject");
    final custom = find.byKey(const Key("custom-subject"));
    expect(tester.getSize(add).width, lessThan(tester.getSize(custom).width));
    expect(tester.getTopLeft(add).dx, tester.getTopLeft(custom).dx);
    await tester.tap(find.byKey(const ValueKey("edit-study-subject-$subject")));
    await tester.pumpAndSettle();
    final label = find.text("Language subject");
    final row = find.ancestor(of: label, matching: find.byType(SwitchListTile));
    final labelStart = tester.getTopLeft(label).dx;
    final press = await tester.startGesture(tester.getCenter(label));
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getTopLeft(label).dx - tester.getTopLeft(row).dx,
      greaterThanOrEqualTo(12),
    );
    expect(tester.getTopLeft(label).dx, labelStart);
    await press.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text("AI drawing"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, "On"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Interactive interfaces (A2UI)"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, "Off"));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, "Save"));
      await c.preferences.whenIdle;
    });
    await tester.pumpAndSettle();

    expect(c.preferences.subjectSettings(subject), (
      language: true,
      drawing: true,
      a2ui: false,
    ));
    expect(c.preferences.isLanguageSubject(subject), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets("subject order can be changed and is used by study switcher", (
    tester,
  ) async {
    late Directory root;
    late _DelayedSubjectsController controller;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp("tixun-subject-order");
      controller = _DelayedSubjectsController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize(seed: false);
      await controller.setLearningSubjects(["英语", "数学", "语文"]);
    });
    final scope = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
    );
    addTearDown(() async {
      scope.dispose();
      await controller.db.close();
      await root.delete(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const TixunApp()),
    );
    scope.read(routerProvider).go("/settings/subjects");
    await tester.pumpAndSettle();
    expect(find.text("已选 3 / 20 个科目"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final order = ["英语", "数学", "语文"];
    final savedOrder = order.toList()
      ..sort((a, b) {
        final aY = tester
            .getTopLeft(find.byKey(ValueKey("selected-study-subject-$a")))
            .dy;
        final bY = tester
            .getTopLeft(find.byKey(ValueKey("selected-study-subject-$b")))
            .dy;
        return aY.compareTo(bY);
      });
    expect(savedOrder, isNot(order));

    expect(find.byKey(const Key("save-subjects")), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(controller.learningSubjects, savedOrder);

    scope.read(routerProvider).go("/study");
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("subject-switch")));
    await tester.pumpAndSettle();
    final menuPositions = savedOrder
        .map((subject) => tester.getTopLeft(find.text(subject)).dy)
        .toList();
    expect(menuPositions, orderedEquals([...menuPositions]..sort()));

    scope.read(routerProvider).go("/settings/subjects");
    await tester.pumpAndSettle();
    controller.saveGate = Completer<void>();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    expect(
      tester
              .widget<TextField>(find.byKey(const Key("custom-subject")))
              .enabled ??
          true,
      isTrue,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(ValueKey("remove-study-subject-${savedOrder.first}")),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip).first).onSelected,
      isNotNull,
    );
    controller.saveGate!.complete();
    controller.saveGate = null;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    scope.read(routerProvider).go("/settings/python");
    tester.view.physicalSize = const Size(1280, 844);
    // Mount the route before giving real filesystem IO time outside fakeAsync.
    // Settling first would wait forever on the workspace loading indicator.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final pythonContent = tester.getRect(
      find.byKey(const Key("python-policy")),
    );
    expect(pythonContent.center.dx, closeTo((203 + 1280) / 2, 1));
    expect(pythonContent.width, lessThanOrEqualTo(760));

    scope.read(routerProvider).go("/settings/ai-usage");
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("AI 用量"), findsOneWidget);
    expect(find.byKey(const Key("add-ai-model-price")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
