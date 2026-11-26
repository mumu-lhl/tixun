import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/theme.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/lexical_form.dart";
import "package:tixun/features/language_learning/lexical_form_store.dart";
import "package:tixun/features/language_learning/vocabulary_ai.dart";
import "package:tixun/features/language_learning/vocabulary_batch.dart";
import "package:tixun/features/language_learning/vocabulary_trash_screen.dart";

import "../../support/quick_lookup.dart" show quickTestConfig;

class _RevisionProvider implements ChatProvider {
  final requested = <String>[];

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        final input = jsonDecode(request.messages.single.text) as Map;
        final form = input["form"] as String;
        requested.add(form);
        yield AiChunk(
          completed: true,
          text: jsonEncode({
            "language": "en",
            "entries": [
              {
                "form": form,
                "type": input["type"],
                if (input["type"] == "word") "partOfSpeech": "n.",
                "meaning": input["meaning"],
                "example": "We discussed $form today.",
                "translation": "That was our topic today.",
              },
            ],
          }),
        );
      });
}

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  const shared = VocabularyEntry(
    form: "take off",
    meaning: "leave the ground",
    type: LexicalType.phrasalVerb,
    forms: [LexicalFormDraft("took off", Inflection.past)],
  );
  const ticket = VocabularyEntry(form: "ticket", meaning: "a travel pass");
  const brake = VocabularyEntry(form: "brake", meaning: "a stopping device");
  final now = DateTime.utc(2026, 1, 1);
  final isWordInTrash = isA<AppFormatException>().having(
    (e) => e.code,
    "code",
    AppErrorCode.languageWordInTrash,
  );

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
  });
  tearDown(() async {
    await store.whenIdle;
    store.dispose();
    await db.close();
  });

  Future<void> save(
    String group,
    List<VocabularyEntry> entries, {
    VocabularyProvenance? provenance,
  }) => store.saveEntries(
    language: "en",
    groupTitle: group,
    groupType: VocabularyGroupType.topic,
    entries: entries,
    provenance: provenance,
    now: now,
  );

  Future<LearningVocabularyGroup> group(String title) async =>
      (await store.groupNamed("en", title))!;

  test("trash hides shared words from both groups and practice, then restores FSRS and history", () async {
    await save("Air travel", [shared]);
    await save("Transport", [shared]);
    final airTravel = await group("Air travel");
    final transport = await group("Transport");
    final card = (await store.cards(language: "en")).single;
    final ids = [card.sense.id];
    await store.recordRecall(
      attemptId: "first-review",
      senseId: card.sense.id,
      rating: RecallRating.good,
      groupPrompt: false,
      now: now,
    );
    final progress = await db.select(db.learningReviewSchedules).getSingle();
    expect(await store.countDue("en", now: progress.dueAt), 1);
    expect(await store.formPractice("en"), hasLength(1));

    await store.moveToTrash(ids);
    for (final id in [airTravel.id, transport.id]) {
      expect(await store.cards(language: "en", groupId: id), isEmpty);
      expect(await store.groupExpressions(id), isEmpty);
    }
    expect(await store.countDue("en", now: progress.dueAt), 0);
    expect(
      await store.recallCards(
        language: "en",
        now: progress.dueAt,
        limit: 10,
        allGroups: true,
        practiceOnly: true,
      ),
      isEmpty,
    );
    expect(await store.formPractice("en"), isEmpty);
    expect((await store.trashedCards("en").first).single.sense.id, ids.single);
    expect(await store.trashedExpressions("en"), {"take off"});
    expect(await store.existingGroupsForEntries("en", [shared]), {shared: []});
    await expectLater(save("Transport", [shared]), throwsA(isWordInTrash));

    await store.restoreVocabulary(ids);
    expect(await store.trashedCards("en").first, isEmpty);
    for (final id in [airTravel.id, transport.id]) {
      expect(
        (await store.cards(language: "en", groupId: id)).single.sense,
        card.sense,
      );
    }
    expect(await db.select(db.learningReviewSchedules).getSingle(), progress);
    expect(
      (await db.select(db.learningEvidence).getSingle()).id,
      "first-review",
    );
    expect(await store.formPractice("en"), hasLength(1));
  });

  test("AI save rejects changed senses and spacing in trash, and hard delete removes only trashed cards", () async {
    const otherSense = VocabularyEntry(
      form: "take off",
      meaning: "remove clothing",
      type: LexicalType.phrasalVerb,
    );
    await save("Transport", [shared, ticket, otherSense]);
    final cards = await store.cards(language: "en");
    final trashedCard = cards.singleWhere(
      (c) => c.sense.meaning == shared.meaning,
    );
    final activeCard = cards.singleWhere((c) => c.item.form == ticket.form);
    await store.moveToTrash([trashedCard.sense.id]);
    const paraphrase = VocabularyEntry(
      form: " TAKE   OFF ",
      meaning: "fly upward",
    );
    final provenance = VocabularyProvenance(
      batchId: "generation",
      model: "test",
      promptVersion: 1,
      generatedAt: now,
      mock: false,
    );
    await expectLater(
      save("Different group", [brake, paraphrase], provenance: provenance),
      throwsA(isWordInTrash),
    );
    expect(await store.groupNamed("en", "Different group"), isNull);
    await store.deleteTrashedVocabulary([
      trashedCard.sense.id,
      activeCard.sense.id,
    ]);
    expect(await store.trashedCards("en").first, isEmpty);
    expect(await db.select(db.learningLexicalForms).get(), isEmpty);
    expect(await db.select(db.learningReviewSchedules).get(), hasLength(2));
    expect(await db.select(db.learningGroupItems).get(), hasLength(2));
    expect(await db.select(db.learningLexicalItems).get(), hasLength(2));
    expect(
      (await store.cards(language: "en")).map((c) => c.sense.meaning),
      unorderedEquals([otherSense.meaning, ticket.meaning]),
    );
    await store.restoreVocabulary([trashedCard.sense.id]);
    expect(await store.cards(language: "en"), hasLength(2));
    await save("Different group", [brake, paraphrase], provenance: provenance);
    expect(await store.cards(language: "en"), hasLength(4));
    expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    bool ready() =>
        finder.evaluate().isNotEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty;
    for (var i = 0; i < 200 && !ready(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
    expect(ready(), isTrue);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });
  }

  Widget app(Widget home) => MaterialApp(
    theme: appTheme(Brightness.light),
    locale: const Locale("en"),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  for (final width in [320.0, 1200.0]) {
    testWidgets(
      "single and bulk trash, restore and confirmed deletion at width $width",
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final transport = await tester.runAsync(() async {
          await save("Transport", [shared, ticket, brake]);
          return group("Transport");
        });
        await tester.runAsync(
          () => tester.pumpWidget(
            app(
              VocabularyBatch(
                store: store,
                language: "en",
                mode: VocabularyMode.study,
                group: transport,
              ),
            ),
          ),
        );
        await waitFor(tester, find.text("brake"));
        final ticketCard = find.ancestor(
          of: find.text("ticket"),
          matching: find.byType(Card),
        );
        await tap(
          tester,
          find.descendant(
            of: ticketCard,
            matching: find.byTooltip("More actions"),
          ),
        );
        await tap(tester, find.text("Move to trash"));
        await tap(tester, find.widgetWithText(FilledButton, "Move to trash"));
        await waitFor(tester, find.text("brake"));
        expect(find.text("ticket"), findsNothing);

        await tap(tester, find.byTooltip("Select words"));
        await tap(tester, find.widgetWithText(CheckboxListTile, "brake"));
        await tap(tester, find.widgetWithText(CheckboxListTile, "take off"));
        expect(find.text("2 words selected"), findsOneWidget);
        await tap(tester, find.widgetWithText(OutlinedButton, "Move to trash"));
        await tap(tester, find.widgetWithText(FilledButton, "Move to trash"));
        await waitFor(tester, find.text("No cards in this batch."));
        expect(tester.takeException(), isNull);

        await tester.runAsync(
          () => tester.pumpWidget(
            app(VocabularyTrashScreen(store: store, language: "en")),
          ),
        );
        await waitFor(tester, find.text("ticket"));
        await tap(tester, find.widgetWithText(CheckboxListTile, "ticket"));
        await tap(tester, find.widgetWithText(FilledButton, "Restore"));
        await waitFor(tester, find.text("0 words selected"));
        expect(find.text("ticket"), findsNothing);
        await tap(tester, find.widgetWithText(CheckboxListTile, "brake"));
        await tap(tester, find.widgetWithText(CheckboxListTile, "take off"));
        await tap(
          tester,
          find.widgetWithText(OutlinedButton, "Delete permanently"),
        );
        expect(
          find.textContaining("Permanently delete 2 words"),
          findsOneWidget,
        );
        await tap(tester, find.text("Cancel"));
        expect(find.text("brake"), findsOneWidget);
        await tap(
          tester,
          find.widgetWithText(OutlinedButton, "Delete permanently"),
        );
        await tap(
          tester,
          find.widgetWithText(FilledButton, "Delete permanently"),
        );
        await waitFor(tester, find.text("Trash is empty"));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          expect(
            (await store.cards(language: "en")).single.item.form,
            "ticket",
          );
          expect(await db.select(db.learningLexicalSenses).get(), hasLength(1));
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets(
    "single and bulk regeneration sends only selected words and keeps their IDs",
    (tester) async {
      final provider = _RevisionProvider();
      late Map<String, String> before;
      await tester.runAsync(() async {
        await save("Transport", [shared, ticket, brake]);
        before = {
          for (final card in await store.cards(language: "en"))
            card.item.form: card.sense.id,
        };
        await tester.pumpWidget(
          app(
            VocabularyBatch(
              store: store,
              mode: VocabularyMode.study,
              language: "en",
              config: quickTestConfig,
              ai: VocabularyAi(provider, usageStore: AiUsageStore(db)),
            ),
          ),
        );
      });
      await waitFor(tester, find.text("ticket"));
      final ticketCard = find.ancestor(
        of: find.text("ticket"),
        matching: find.byType(Card),
      );
      await tap(
        tester,
        find.descendant(
          of: ticketCard,
          matching: find.byTooltip("More actions"),
        ),
      );
      await tap(tester, find.text("Regenerate and compare"));
      await waitFor(tester, find.byTooltip("Select words"));
      await waitFor(tester, find.text("ticket"));
      expect(provider.requested, ["ticket"]);

      await tap(tester, find.byTooltip("Select words"));
      await tap(tester, find.widgetWithText(CheckboxListTile, "brake"));
      await tap(tester, find.widgetWithText(CheckboxListTile, "take off"));
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, "Regenerate and compare"),
      );
      await waitFor(tester, find.byTooltip("Select words"));
      expect(provider.requested, ["ticket", "brake", "take off"]);
      await tester.runAsync(() async {
        final after = await store.cards(language: "en");
        expect({for (final c in after) c.item.form: c.sense.id}, before);
        for (final card in after) {
          expect(card.sense.example, "We discussed ${card.item.form} today.");
        }
      });
    },
  );
}
