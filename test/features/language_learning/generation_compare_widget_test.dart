import "dart:convert";

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
  for (final (width, hideSolutions) in [
    (320.0, true),
    (1200.0, true),
    (1200.0, false),
  ]) {
    testWidgets(
      "generation comparison retains both candidates at $width (hideSolutions: $hideSolutions)",
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
          String output(String version) => !hideSolutions
              ? "$version material"
              : jsonEncode({
                  "sentences": [
                    {
                      "text": "$version material",
                      "hint": "Private $version hint",
                      "translation": "Private $version translation",
                      "target": {"meaning": "Private $version meaning"},
                      "check": {
                        "question": "$version question",
                        "choices": ["$version option A", "$version option B"],
                        "correctIndex": 1,
                        "explanation": "Private $version explanation",
                      },
                    },
                  ],
                });
          final feature = hideSolutions
              ? "language_context_understanding"
              : "test";
          original = await store.capture(
            feature: feature,
            request: request,
            config: quickTestConfig,
            output: output("Original"),
            format: hideSolutions ? "json" : "markdown",
            cancel: CancelToken(),
          );
          candidate = await store.capture(
            feature: feature,
            request: request,
            config: quickTestConfig.copyWith(model: "better-model"),
            output: output("New"),
            format: hideSolutions ? "json" : "markdown",
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
                      hideSolutions: hideSolutions,
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
        for (final version in ["Original", "New"]) {
          expect(find.textContaining("$version material"), findsOneWidget);
          if (hideSolutions) {
            expect(find.textContaining("$version question"), findsOneWidget);
            expect(find.textContaining("$version option A"), findsOneWidget);
            expect(find.textContaining("$version option B"), findsOneWidget);
          }
        }
        if (hideSolutions) {
          expect(find.textContaining("correctIndex"), findsNothing);
          expect(find.textContaining("Private"), findsNothing);
          expect(original.output, contains("Private Original explanation"));
          expect(candidate.output, contains("Private New explanation"));
        }
        await tester.tap(find.text("Use original"));
        await tester.pumpAndSettle();
        expect(chosen, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
