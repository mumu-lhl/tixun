import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/generation_store.dart";
import "package:tixun/features/language_learning/generation_ui.dart";

import "../../support/quick_lookup.dart" show quickTestConfig;

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      "generation comparison retains both candidates and lets readers choose at $width",
      (tester) async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        late LanguageGenerationRun original, candidate;
        await tester.runAsync(() async {
          final store = LanguageGenerationStore(db);
          final request = AiRequest(
            instructions: "prompt",
            messages: [const AiMessage.user("input")],
          );
          original = await store.capture(
            feature: "test",
            request: request,
            config: quickTestConfig,
            output: "Original material",
            format: "markdown",
            cancel: CancelToken(),
          );
          candidate = await store.capture(
            feature: "test",
            request: request,
            config: quickTestConfig.copyWith(model: "better-model"),
            output: "New material",
            format: "markdown",
            cancel: CancelToken(),
          );
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        bool? chosen;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    chosen = await compareLanguageGenerations(
                      context,
                      original,
                      candidate,
                      CancelToken(),
                    );
                  },
                  child: const Text("Compare"),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text("Compare"));
        await tester.pumpAndSettle();
        expect(find.text("Original material"), findsOneWidget);
        expect(find.text("New material"), findsOneWidget);
        await tester.tap(find.text("Use original"));
        await tester.pumpAndSettle();
        expect(chosen, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
