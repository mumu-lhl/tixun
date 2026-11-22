import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/ui/learning_markdown.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_ai.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_action_editor.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_models.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_store.dart";
import "package:dio/dio.dart" show CancelToken;

import "support/quick_lookup.dart";

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets("lookup and history work at viewport width $width", (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 960);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final provider = QuickTestProvider();
      late AppController controller;
      late Directory root;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("tixun-lookup-widget");
        controller = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          provider,
        );
        await controller.initialize(seed: false);
        await controller.setLanguage("en");
        final store = controller.language;
        await store.ensureQuickActions();
        final custom = await store.saveQuickAction(
          quickActionDefaults(
            "old-action",
            0,
            DateTime.now(),
          ).copyWith(name: "Old expression task", prompt: "Rephrase {input}"),
        );
        final ai = QuickLookupAi(
          store,
          provider,
          controller.config,
          AiUsageStore(controller.db),
        );
        await ai.lookup(
          quickTestQuery(custom, input: "old custom input"),
          CancelToken(),
        );
        await store.deleteQuickAction(custom.id);
      });

      final scope = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((_) => controller)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const TixunApp()),
      );

      Future<void> settled() async {
        // Advance Flutter animations and give database futures a real turn.
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(const Duration(milliseconds: 80));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pump();
      }

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.runAsync(() => tester.tap(target));
        await settled();
      }

      final router = scope.read(routerProvider);
      router.go("/language");
      await settled();
      await tap(find.text("Language quick lookup"));
      await settled();
      expect(find.byKey(const ValueKey("quick-search")), findsNothing);
      expect(find.text("All tasks"), findsOneWidget);
      expect(find.text("old custom input"), findsOneWidget);

      await tap(find.byKey(const ValueKey("language_meaning")));
      final input = find.byKey(const ValueKey("quick-input"));
      await tester.enterText(input, "pleasure");
      await tester.pumpAndSettle();
      await tap(find.text("Look up"));
      await settled();
      expect(provider.requests, hasLength(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey("quick-current-result")),
          matching: find.text("pleasure"),
        ),
        findsOneWidget,
      );
      expect(find.text("n. 快乐、愉悦；荣幸。"), findsWidgets);
      expect(find.byType(LearningMarkdown), findsOneWidget);

      router.go("/language");
      await settled();
      await tap(find.text("Language quick lookup"));
      final historyRow = find.text("pleasure");
      expect(historyRow, findsOneWidget);
      expect(find.byType(LearningMarkdown), findsNothing);
      await tap(historyRow);
      expect(find.byType(LearningMarkdown), findsOneWidget);
      await tap(historyRow);
      expect(find.byType(LearningMarkdown), findsNothing);

      final filter = find.byKey(const ValueKey("quick-filter"));
      await tap(filter);
      await tap(find.text("Old expression task (Deleted task)").last);
      await settled();
      expect(find.text("old custom input"), findsOneWidget);
      expect(historyRow, findsNothing);

      await tap(filter);
      await tap(find.text("What does it mean?").last);
      await settled();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey("language_express")))
            .selected,
        true,
      );
      expect(historyRow, findsOneWidget);
      expect(find.text("old custom input"), findsNothing);

      await tap(find.byTooltip("Search history"));
      final search = find.byKey(const ValueKey("quick-search"));
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, true);
      await tester.enterText(search, "ENJOYMENT");
      await tester.pump(const Duration(milliseconds: 220));
      await settled();
      expect(historyRow, findsOneWidget);
      await tester.enterText(search, "not present");
      await tester.pump(const Duration(milliseconds: 220));
      await settled();
      expect(find.text("No matching lookups."), findsOneWidget);
      await tap(find.byTooltip("Close"));
      await settled();
      expect(search, findsNothing);
      expect(historyRow, findsOneWidget);
      await tap(find.byTooltip("Search history"));
      await tester.binding.handlePopRoute();
      await settled();
      expect(search, findsNothing);
      expect(router.state.uri.path, "/language/quick");

      await tap(historyRow);
      await tap(find.text("Add to vocabulary"));
      await tap(find.text("Confirm"));
      await tester.enterText(
        find.widgetWithText(TextFormField, "Group name"),
        "Useful expressions",
      );
      await tap(find.text("Save"));
      await settled();
      await tester.runAsync(() async {
        final groups = await controller.language.groups("en").first;
        expect(groups.single.title, "Useful expressions");
        expect(
          (await controller.db.select(controller.db.learningLexicalItems).get())
              .single
              .form,
          "pleasure",
        );
      });

      await tap(find.text("Add to sentences"));
      await tap(find.text("Save"));
      await settled();
      await tester.runAsync(() async {
        expect(
          await controller.db
              .select(controller.db.learningSentenceBatches)
              .get(),
          hasLength(1),
        );
        expect(
          await controller.db
              .select(controller.db.languageQuickLearningLinks)
              .get(),
          hasLength(2),
        );
        expect(
          await controller.db.select(controller.db.learningEvidence).get(),
          isEmpty,
        );
      });

      ScaffoldMessenger.of(tester.element(historyRow)).clearSnackBars();
      await settled();
      await tap(find.text("Discuss in Chat"));
      await settled();
      expect(router.state.uri.path, "/chat");
      expect(controller.selected!.draft, contains("pleasure"));
      expect(controller.selected!.draft, contains("**Pleasure**"));
      expect(controller.selected!.draft, contains("language_meaning"));
      expect(controller.messages, isEmpty);
      expect(provider.requests, hasLength(2));
      router.pop();
      await settled();
      expect(router.state.uri.path, "/language/quick");
      expect(historyRow, findsOneWidget);
      expect(find.byType(LearningMarkdown), findsOneWidget);
      expect(tester.takeException(), isNull);

      late LanguageQuickAction action;
      await tester.runAsync(() async {
        action = (await controller.language.quickActions()).first;
      });
      final editing = editQuickAction(
        tester.element(historyRow),
        controller.language,
        action,
      );
      await settled();
      expect(
        find.widgetWithText(TextFormField, "Short description"),
        findsNothing,
      );
      final prompt = find.widgetWithText(TextFormField, "Task instructions");
      await tester.enterText(prompt, "{unsupported}");
      await tap(find.widgetWithText(FilledButton, "Save"));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text("Enter task instructions using only supported variables."),
        findsOneWidget,
      );
      await tester.enterText(prompt, "Explain {input}");
      await tap(find.byKey(const Key("quick-action-advanced")));
      final description = find.widgetWithText(
        TextFormField,
        "Short description",
      );
      await tester.ensureVisible(description);
      await tester.enterText(description, "Custom description");
      await tap(find.byKey(const Key("quick-action-advanced")));
      await tap(find.widgetWithText(FilledButton, "Save"));
      await tester.runAsync(() => editing);
      await settled();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.runAsync(() async {
        final saved = (await controller.language.quickActions()).firstWhere(
          (a) => a.id == action.id,
        );
        expect(saved.description, "Custom description");
        expect(saved.prompt, "Explain {input}");
        expect(saved.sourceLanguage, action.sourceLanguage);
        expect(saved.glossLanguage, action.glossLanguage);
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await settled();
      await tester.runAsync(() async {
        scope.dispose();
        await controller.db.close();
        await root.delete(recursive: true);
      });
    });
  }
}
