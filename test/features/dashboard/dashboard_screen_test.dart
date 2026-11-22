import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/dashboard/daily_learning.dart";
import "package:tixun/features/dashboard/dashboard_screen.dart";
import "package:tixun/features/library/library_providers.dart";
import "package:tixun/features/progress/learning_profile.dart";
import "package:tixun/features/progress/learning_progress.dart";
import "package:tixun/features/review/review_providers.dart";

void main() {
  testWidgets("study prioritizes today's tasks and adapts record shortcuts", (
    tester,
  ) async {
    final (controller, progress) = (await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp("tixun-study-layout");
      final controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize(seed: false);
      await controller.setLearningSubjects(["英语", "数学"]);
      await controller.setSubjectFilter("英语");
      return (controller, await LearningProgress.load(controller.db));
    }))!;
    final scope = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((_) => controller),
        dueCountProvider.overrideWith((_) => 0),
        progressProvider.overrideWith((_) => progress),
        learningProfileProvider.overrideWith((_) => const LearningProfile()),
        studyCountsProvider.overrideWith((_) => (knowledge: 0, mistakes: 0)),
      ],
    );
    addTearDown(() async {
      scope.dispose();
      await controller.shutdown();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale("en"),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final today = find.byType(DailyLearning);
    final language = find.byKey(const Key("open-language-learning"));
    final timeline = find.byKey(const Key("open-timeline"));
    final exams = find.byKey(const Key("open-exams"));
    expect(
      tester.getRect(language).top,
      greaterThan(tester.getRect(today).bottom),
    );
    expect(
      tester.getRect(timeline).top,
      greaterThan(tester.getRect(language).bottom),
    );
    expect(
      tester.getRect(exams).top,
      greaterThanOrEqualTo(tester.getRect(timeline).bottom),
    );

    final expandedTop = tester.getRect(timeline).top;
    await tester.runAsync(() => controller.setSubjectFilter("数学"));
    await tester.pumpAndSettle();
    expect(language, findsNothing);
    expect(tester.getRect(timeline).top, lessThan(expandedTop));

    tester.view.physicalSize = const Size(1280, 1000);
    await tester.pumpAndSettle();
    final dailyRect = tester.getRect(today);
    final timelineRect = tester.getRect(timeline);
    expect(timelineRect.left, greaterThan(dailyRect.right));
    expect(timelineRect.top, closeTo(dailyRect.top, 2));
    expect(tester.getRect(exams).left, closeTo(timelineRect.left, 1));

    // Measure the painted surfaces, not the larger tap targets.
    Rect buttonSurface(Finder button) => tester.getRect(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );
    final chat = buttonSurface(find.byKey(const Key("start-chat")));
    final practice = buttonSurface(find.byKey(const Key("start-practice")));
    final mistake = buttonSurface(
      find.widgetWithText(OutlinedButton, "Add a mistake"),
    );
    expect(practice.top, closeTo(chat.top, 0.1));
    expect(practice.bottom, closeTo(chat.bottom, 0.1));
    expect(mistake.top, closeTo(chat.top, 0.1));
    expect(mistake.bottom, closeTo(chat.bottom, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
