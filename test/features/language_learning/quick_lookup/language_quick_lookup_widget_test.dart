import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/app.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/ui/learning_markdown.dart";
import "package:tixun/features/language_learning/fsrs.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_ai.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_action_editor.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_models.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_store.dart";
import "package:dio/dio.dart" show CancelToken;

import "../../../support/quick_lookup.dart";

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
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.3);
        await tester.pump();
        await tester.runAsync(() => tester.tap(target));
        await settled();
      }

      final router = scope.read(routerProvider);
      router.go("/language");
      await settled();
      expect(
        find.widgetWithText(ListTile, "Recommended practice"),
        findsOneWidget,
      );
      expect(find.text("Multilingual beginner courses"), findsOneWidget);
      expect(find.text("Review due cards"), findsNothing);
      expect(
        find.textContaining("vocabulary cards due for review"),
        findsNothing,
      );
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
      final firstCard = find.ancestor(
        of: historyRow,
        matching: find.byType(Card),
      );
      final secondCard = find.ancestor(
        of: find.text("old custom input"),
        matching: find.byType(Card),
      );
      expect(
        tester.getTopLeft(secondCard).dy - tester.getBottomLeft(firstCard).dy,
        greaterThanOrEqualTo(8),
      );
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

      await tester.runAsync(() async {
        final sense = await controller.db
            .select(controller.db.learningLexicalSenses)
            .getSingle();
        await controller.language.recordRecall(
          attemptId: "previous-recall",
          senseId: sense.id,
          rating: RecallRating.again,
          groupPrompt: false,
          now: DateTime.now().subtract(const Duration(days: 7)),
        );
      });
      // Reopen with no composer result, so regeneration must use the chosen
      // history entry. The deleted task must still work from its snapshot.
      if (width == 360) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.45;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      router.go("/language");
      await settled();
      expect(find.widgetWithText(ListTile, "Review due cards"), findsOneWidget);
      expect(
        find.textContaining("vocabulary cards due for review"),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tap(find.text("Language quick lookup"));
      final store = controller.language;
      final originalRows = (await tester.runAsync(() => store.quickHistory()))!;
      final pleasure = originalRows.firstWhere((r) => r.input == "pleasure");
      final oldCustom = originalRows.firstWhere(
        (r) => r.input == "old custom input",
      );
      Finder row(String id) => find.byKey(ValueKey(id));
      Finder checkbox(String id) =>
          find.descendant(of: row(id), matching: find.byType(CheckboxListTile));

      Future<void> revealInHistory(Finder target) async {
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            160,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(target);
      }

      Future<void> selectRows(List<String> ids) async {
        await tap(find.byTooltip("Select lookups"));
        for (final id in ids) {
          await revealInHistory(checkbox(id));
          await tap(checkbox(id));
        }
      }

      await revealInHistory(row(oldCustom.id));
      await tap(row(oldCustom.id));
      await tap(
        find.descendant(
          of: row(oldCustom.id),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tap(find.text("Regenerate"));
      expect(provider.requests, hasLength(3));
      expect(
        provider.requests.last.instructions,
        contains("Rephrase the input field in the user data"),
      );
      expect(find.text("Regenerated 1 of 1 lookup."), findsOneWidget);
      final messenger = ScaffoldMessenger.of(tester.element(input));
      messenger.removeCurrentSnackBar();
      await settled();

      await revealInHistory(row(pleasure.id));
      await tester.longPress(
        find.descendant(of: row(pleasure.id), matching: find.byType(ListTile)),
      );
      await settled();
      expect(
        tester.widget<CheckboxListTile>(checkbox(pleasure.id)).value,
        true,
      );
      expect(find.text("Selected: 1"), findsOneWidget);
      await revealInHistory(checkbox(oldCustom.id));
      await tap(checkbox(oldCustom.id));
      final regenerate = find.widgetWithText(FilledButton, "Regenerate");
      final move = find.widgetWithText(OutlinedButton, "Move to Trash");
      expect(tester.getSize(regenerate).height, tester.getSize(move).height);
      expect(find.text("Selected: 2"), findsOneWidget);
      final bulk = find.widgetWithText(OutlinedButton, "Add to study");
      expect(tester.getSize(bulk).height, tester.getSize(move).height);
      await tap(bulk);
      final batchDialog = find.byType(AlertDialog);
      Finder inDialog(Finder matching) =>
          find.descendant(of: batchDialog, matching: matching);
      final candidates = inDialog(
        find.widgetWithText(CheckboxListTile, "pleasure"),
      );
      expect(candidates, findsNWidgets(2));
      await tap(candidates.first);
      await tap(inDialog(find.text("Next")));
      await tester.enterText(
        find.widgetWithText(TextFormField, "Group name"),
        "Bulk vocabulary",
      );
      await tap(inDialog(find.text("Save")));
      expect(
        find.text("Lookups added: 1. Skipped: 0. Failed: 0."),
        findsOneWidget,
      );
      expect(provider.requests, hasLength(3));
      await tester.runAsync(() async {
        expect(
          (await store.groups("en").first).map((group) => group.title),
          contains("Bulk vocabulary"),
        );
      });
      messenger.removeCurrentSnackBar();
      await settled();
      await tap(regenerate);
      expect(provider.requests, hasLength(5));
      expect(
        [
          for (final request in provider.requests.skip(3))
            (jsonDecode(request.messages.single.text) as Map)["input"],
        ],
        ["pleasure", "old custom input"],
      );
      expect(find.text("Regenerated 2 of 2 lookups."), findsOneWidget);
      final afterBatch = (await tester.runAsync(() => store.quickHistory()))!;
      expect(afterBatch, hasLength(5));
      expect(
        afterBatch.map((r) => r.id),
        containsAll([pleasure.id, oldCustom.id]),
      );
      messenger.removeCurrentSnackBar();
      await settled();

      // The first item completes, the second remains in progress, and the
      // third must never be submitted after stopping.
      final pending = StreamController<AiChunk>();
      final normalReply = provider.reply;
      provider.reply = (cancel) =>
          provider.requests.length == 7 ? pending.stream : normalReply(cancel);
      await selectRows(afterBatch.take(3).map((r) => r.id).toList());
      await tap(regenerate);
      expect(provider.requests, hasLength(7));
      expect(find.text("Regenerating lookup 2 of 3…"), findsOneWidget);
      await tap(find.text("Stop generating"));
      expect(provider.requests, hasLength(7));
      expect(
        find.text("Generation stopped. Regenerated 1 of 3 lookups."),
        findsOneWidget,
      );
      expect(await tester.runAsync(() => store.quickHistory()), hasLength(6));
      unawaited(pending.close());
      messenger.removeCurrentSnackBar();
      await settled();

      await selectRows([pleasure.id, oldCustom.id]);
      expect(find.text("Delete permanently"), findsNothing);
      await tap(move);
      expect(row(pleasure.id), findsNothing);
      expect(row(oldCustom.id), findsNothing);
      final trashed = (await tester.runAsync(
        () => store.quickHistory(trashed: true),
      ))!;
      expect(
        trashed.map((r) => r.id),
        unorderedEquals([pleasure.id, oldCustom.id]),
      );
      await tap(find.byTooltip("Lookup Trash"));
      await tap(checkbox(pleasure.id));
      await tap(find.text("Restore"));
      expect(checkbox(pleasure.id), findsNothing);

      await tap(checkbox(oldCustom.id));
      final permanently = find.text("Delete permanently");
      await tap(permanently);
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.textContaining("This cannot be undone."), findsOneWidget);
      await tap(find.descendant(of: dialog, matching: find.text("Cancel")));
      expect(checkbox(oldCustom.id), findsOneWidget);
      await tap(permanently);
      await tap(find.descendant(of: dialog, matching: permanently));
      expect(find.text("Trash is empty"), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settled();
      await tester.runAsync(() async {
        expect(await store.quickLookup(pleasure.id), isNotNull);
        expect(await store.quickHistory(trashed: true), isEmpty);
        expect(
          (await controller.db.select(controller.db.languageQuickLookups).get())
              .map((row) => row.id),
          isNot(contains(oldCustom.id)),
        );
      });
      expect(tester.takeException(), isNull);

      final missing = (await tester.runAsync(() async {
        final action = (await store.quickActions()).first;
        return store.saveQuickLookup(
          quickTestQuery(action, input: "Make a difference"),
          const QuickAnswer(
            "Have an effect",
            "It made a difference. This means it had an effect.",
            QuickCandidates([], null),
          ),
          config: quickTestConfig,
          key: "bulk-test-missing",
        );
      }))!;
      router.go("/language");
      await settled();
      await tap(find.text("Language quick lookup"));
      await revealInHistory(row(missing.id));
      await tap(row(missing.id));
      final resultMenu = find.descendant(
        of: row(missing.id),
        matching: find.byType(PopupMenuButton<String>),
      );

      Future<void> autoAdd() async {
        await tap(resultMenu);
        await tap(
          find.widgetWithText(PopupMenuItem<String>, "Auto-add with AI"),
        );
        expect(
          inDialog(find.textContaining("charges may apply")),
          findsOneWidget,
        );
      }

      provider.reply = (_) => Stream.fromIterable([
        const AiChunk(
          text:
              '{"vocabulary":[{"form":"make a difference",'
              '"type":"phrase","meaning":"have an effect"}]}',
        ),
        const AiChunk(completed: true),
      ]);
      await autoAdd();
      await tap(inDialog(find.text("Next")));
      await tester.enterText(
        find.widgetWithText(TextFormField, "Group name"),
        "Extracted vocabulary",
      );
      await tap(inDialog(find.text("Save")));
      expect(provider.requests, hasLength(8));
      expect(jsonDecode(provider.requests.last.messages.single.text), {
        "input": "Make a difference",
        "answer": "It made a difference. This means it had an effect.",
        "glossLanguage": "zh",
        "target": "vocabulary",
      });
      expect(provider.requests.last.instructions, contains("as data"));
      expect(provider.requests.last.tools, isEmpty);

      Future<void> chooseSentences() async {
        await tap(inDialog(find.text("Add to vocabulary")));
        await tap(find.widgetWithText(MenuItemButton, "Add to sentences"));
      }

      final studyMessenger = ScaffoldMessenger.of(tester.element(resultMenu));
      studyMessenger.removeCurrentSnackBar();
      await settled();
      final extractionPending = StreamController<AiChunk>();
      final vocabularyReply = provider.reply;
      provider.reply = (_) => extractionPending.stream;
      await autoAdd();
      await chooseSentences();
      await tap(inDialog(find.text("Save")));
      expect(find.textContaining("Adding to study"), findsOneWidget);
      await tap(find.text("Stop adding"));
      unawaited(extractionPending.close());
      expect(find.textContaining("Stopped adding."), findsOneWidget);
      expect(find.text("Stop adding"), findsNothing);
      studyMessenger.removeCurrentSnackBar();
      await settled();
      provider.reply = vocabularyReply;

      // The wrong response shape must not add any sentence.
      await autoAdd();
      await chooseSentences();
      await tap(inDialog(find.text("Save")));
      expect(provider.requests, hasLength(10));
      await tester.runAsync(() async {
        final links = await controller.db
            .select(controller.db.languageQuickLearningLinks)
            .get();
        expect(
          links.where((link) => link.lookupId == missing.id).single.senseId,
          isNotNull,
        );
      });

      provider.reply = (_) => Stream.fromIterable([
        const AiChunk(
          text:
              '{"sentence":{"text":"It made a difference.",'
              '"gloss":"它起到了作用。"}}',
        ),
        const AiChunk(completed: true),
      ]);
      await autoAdd();
      await chooseSentences();
      await tap(inDialog(find.text("Save")));
      expect(provider.requests, hasLength(11));
      await tester.runAsync(() async {
        final links = await controller.db
            .select(controller.db.languageQuickLearningLinks)
            .get();
        final extracted = links.where((link) => link.lookupId == missing.id);
        expect(extracted, hasLength(2));
        expect(
          extracted.where((link) => link.sentenceBatchId != null),
          hasLength(1),
        );
        final tasks = await controller.db
            .select(controller.db.languageGenerationTasks)
            .get();
        final extractionTasks = tasks.where(
          (task) => task.feature == "language_quick_extract",
        );
        expect(extractionTasks, hasLength(2));
        final runIds = extractionTasks.map((task) => task.activeRunId).toSet();
        final runLinks = await controller.db
            .select(controller.db.languageGenerationLinks)
            .get();
        expect(
          runLinks
              .where((link) => runIds.contains(link.runId))
              .map((link) => (link.kind, link.contentId)),
          unorderedEquals([
            (
              "vocabulary",
              extracted.singleWhere((row) => row.senseId != null).senseId,
            ),
            (
              "sentence_batch",
              extracted
                  .singleWhere((row) => row.sentenceBatchId != null)
                  .sentenceBatchId,
            ),
          ]),
        );
      });
      expect(tester.takeException(), isNull);

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
