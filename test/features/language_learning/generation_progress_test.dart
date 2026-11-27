import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/generation_progress.dart";
import "package:tixun/features/language_learning/generation_activity.dart";

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      "request phases fit width $width and show only confirmed counts",
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final activity = ValueNotifier<GenerationActivity?>(null);
        addTearDown(activity.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LanguageGenerationActivity(activity: activity),
            ),
          ),
        );
        expect(find.text("Preparing"), findsOneWidget);
        activity.value = (
          feature: "language_exam_generation",
          phase: GenerationPhase.generating,
          completed: null,
          total: 5,
        );
        await tester.pump();
        expect(
          find.text("Generating practice questions: 0/5 (0%)"),
          findsOneWidget,
        );
        activity.value = (
          feature: "language_exam_generation",
          phase: GenerationPhase.saving,
          completed: 5,
          total: 5,
        );
        await tester.pump();
        expect(find.text("Saving: 5/5 (100%)"), findsOneWidget);
        activity.value = (
          feature: "language_exam_generation",
          phase: GenerationPhase.comparing,
          completed: null,
          total: null,
        );
        await tester.pump();
        expect(find.text("Waiting for version selection"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    "shows validated counts and updates without motion when disabled",
    (tester) async {
      Widget screen(int count) => MaterialApp(
        locale: const Locale("en"),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LanguageGenerationProgress(
              label: "Generating",
              completed: count,
              total: 20,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(5));
      expect(find.text("Generating: 5/20 (25%)"), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .25,
      );
      await tester.pumpWidget(screen(10));
      await tester.pump();
      expect(find.text("Generating: 10/20 (50%)"), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
    },
  );
}
