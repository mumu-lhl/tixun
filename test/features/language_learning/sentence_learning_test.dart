import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/prompt_settings.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/language_skills.dart";
import "package:tixun/features/language_learning/exam_material.dart";
import "package:tixun/features/language_learning/next_practice.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_batch_store.dart";
import "package:tixun/features/language_learning/sentence_content.dart";
import "package:tixun/features/language_learning/sentence_explanation.dart";
import "package:tixun/features/language_learning/sentence_practice.dart";
import "package:tixun/features/language_learning/sentence_store.dart";

const _config = ProviderConfig(
  id: 1,
  kind: "openai",
  baseUrl: "https://example.com",
  model: "test-model",
  vision: false,
  supportsTools: false,
  thinking: false,
  supportsThinking: false,
  effort: "",
);

class _Provider implements ChatProvider {
  int calls = 0;
  AiRequest? lastRequest;
  bool complete = true;
  bool offline = false;
  Future<void>? pause;
  String response = "The library closes earlier on Saturdays.";

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        expect(
          encodeCompletion(config, request).containsKey("max_tokens"),
          isFalse,
        );
        calls++;
        lastRequest = request;
        await pause;
        if (offline) throw const AiFailure("Offline");
        yield AiChunk(text: response, completed: complete);
      });
}

SentenceCard _card({int revision = 1, bool travel = false}) => SentenceCard(
  id: travel ? "station" : "library",
  text: travel
      ? "The station shuts at noon."
      : "On Saturdays, the library closes at noon rather than at six.",
  translation: "图书馆周六中午关门，不是六点。",
  hint: "“Rather than” contrasts two times.",
  question: "When does it close?",
  choices: const ["At six", "At noon"],
  correctIndex: 1,
  skill: SentenceSkill.detail,
  level: SentenceLevel.beginner,
  revision: revision,
);

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  late _Provider provider;
  late SentenceExplanation explanation;

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
    provider = _Provider();
    explanation = SentenceExplanation(
      store: store,
      provider: provider,
      config: _config,
    );
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  Future<String> explain({int revision = 1, CancelToken? cancel}) =>
      explanation.explain(
        card: _card(revision: revision),
        glossLanguage: "en",
        simpler: false,
        cancel: cancel ?? CancelToken(),
      );

  test(
    "cached explanation works offline for its revision without making a chat",
    () async {
      final first = await explain();
      provider.offline = true;
      expect(await explain(), first);
      expect(provider.calls, 1);
      await expectLater(explain(revision: 2), throwsA(isA<AiFailure>()));
      expect(provider.calls, 2);
      expect(await db.select(db.chatMessages).get(), isEmpty);
      expect(
        await db.select(db.learningInlineExplanations).get(),
        hasLength(1),
      );
    },
  );

  test(
    "changing explanation preferences bypasses the previous cache",
    () async {
      final original = await explain();
      final custom = SentenceExplanation(
        store: store,
        provider: provider,
        config: _config,
        prompts: PromptSettings().update(
          LanguagePrompt.sentenceExplanation.id,
          "Explain the contrasting phrase first.",
        ),
      );
      Future<String> withPreference() => custom.explain(
        card: _card(),
        glossLanguage: "en",
        simpler: false,
        cancel: CancelToken(),
      );
      provider.response = "Rather than contrasts noon with six.";
      expect(await withPreference(), provider.response);
      final request = provider.lastRequest!;
      expect(request.instructions, contains("contrasting phrase first"));
      expect(request.instructions, contains("at most three short sentences"));
      expect(request.tools, isEmpty);
      expect(jsonDecode(request.messages.single.text)["glossLanguage"], "en");
      provider.offline = true;
      expect(await withPreference(), provider.response);
      expect(await explain(), original);
      expect(provider.calls, 2);
    },
  );

  test("learner can retry after an interrupted explanation", () async {
    provider.complete = false;
    await expectLater(explain(), throwsFormatException);
    expect(await db.select(db.learningInlineExplanations).get(), isEmpty);
    provider.complete = true;
    expect(await explain(), "The library closes earlier on Saturdays.");
    expect(provider.calls, 2);
  });

  test(
    "follow-up uses distinct independent checks and a fresh context",
    () async {
      SentenceCard detail(SentenceTopic topic) =>
          _card(travel: topic == SentenceTopic.travel);
      final daily = detail(SentenceTopic.dailyLife);
      final travel = detail(SentenceTopic.travel);
      Future<void> record(
        String id,
        SentenceCard card, {
        bool helped = false,
      }) => store.recordSentence(
        batchId: id,
        card: card,
        rating: SentenceRating.understood,
        selectedIndex: (card.correctIndex + 1) % card.choices.length,
        helpUsed: helped ? {SentenceHelp.hint} : {},
        helpBeforeAnswer: helped ? {SentenceHelp.hint} : {},
      );
      await record("one", daily);
      await record("repeat", daily);
      await record("assisted", travel, helped: true);
      final prior = await suggestSentences(store);
      expect(prior.diagnostic, isTrue);

      await record("independent", travel);
      final suggestion = await suggestSentences(store);
      expect(suggestion.skill, SentenceSkill.sequence);
      expect(suggestion.performance.checked, 0);
      expect(suggestion.performance.correct, 0);
      expect(suggestion.performance.assisted, 0);
      expect(suggestion.exclusions, containsAll([daily.text, travel.text]));
      expect(await store.savedForSentencePlan(suggestion), isEmpty);
    },
  );

  test(
    "a weak skill becomes a bounded request and valid checks are reusable",
    () async {
      for (final (i, topic) in SentenceTopic.values.indexed) {
        final card = _card(travel: topic == SentenceTopic.travel);
        await store.recordSentence(
          batchId: "short-$i",
          card: card,
          rating: SentenceRating.understood,
          helpUsed: const {},
          selectedIndex: (card.correctIndex + 1) % card.choices.length,
        );
      }
      final plan = await suggestSentences(store);
      expect(plan.skill, SentenceSkill.sequence);
      expect(plan.diagnostic, isTrue);
      expect(await store.savedForSentencePlan(plan), isEmpty);
      provider.response = jsonEncode({
        "language": "en",
        "sentences": [
          for (final room in [
            "kitchen",
            "hall",
            "studio",
            "cellar",
            "garage",
          ].take(plan.count))
            {
              "text": "The spare key is in the $room.",
              "hint": "Look for a place.",
              "translation": "Find the spare key in the $room.",
              "level": plan.level.name,
              "skill": plan.skill.name,
              "check": {
                "question": "Where is the spare key?",
                "choices": [room, "bedroom", "porch"],
                "correctIndex": 0,
                "explanation": "The sentence names the $room.",
              },
            },
        ],
      });
      final ai = SentenceBatchAi(provider: provider, config: _config);
      final proposal = await ai.propose(
        topic: SentenceTopic.dailyLife,
        style: plan.style,
        level: plan.level,
        glossLanguage: "en",
        count: plan.count,
        cancel: CancelToken(),
        focus: plan.skill,
        exclude: plan.exclusions,
      );
      expect(provider.calls, 1);
      expect(provider.lastRequest!.tools, isEmpty);
      expect(
        provider.lastRequest!.messages.single.text,
        contains('"focus":"sequence"'),
      );
      expect(provider.lastRequest!.messages.single.text, contains('"exclude"'));
      expect(
        proposal.cards.map((card) => card.choices.length),
        everyElement(3),
      );
      await store.saveSentenceBatch(
        proposal,
        proposal.cards.map((card) => card.id).toSet(),
      );
      final saved = await store.savedForSentencePlan(plan);
      expect(saved, hasLength(plan.count));
      expect(saved.first.correctIndex, 0);
      expect(saved.first.checkExplanation, contains("kitchen"));

      await store.recordSentence(
        batchId: "targeted",
        card: saved.first,
        rating: SentenceRating.partial,
        helpUsed: const {},
        selectedIndex: 0,
      );
      final next = await suggestSentences(store);
      expect(next.performance.checked, 0);
      expect(next.exclusions, contains(saved.first.text));
      expect(await db.select(db.chatMessages).get(), isEmpty);
    },
  );

  test(
    "invalid generated check is rejected without changing saved batches",
    () async {
      final existing = SentenceBatchProposal(
        id: "saved",
        topic: SentenceTopic.dailyLife,
        style: SentenceStyle.written,
        glossLanguage: "en",
        model: "example",
        promptVersion: 2,
        isMock: false,
        generatedAt: DateTime.now(),
        cards: [_card()],
      );
      await store.saveSentenceBatch(existing, {"library"});
      provider.response = jsonEncode({
        "language": "en",
        "sentences": [
          {
            "text": "She arrives on Sunday.",
            "hint": "Look for the day.",
            "translation": "She will be there Sunday.",
            "level": "beginner",
            "skill": "not_a_skill",
            "check": {
              "question": "When?",
              "choices": ["Sunday", "Monday", "Tuesday"],
              "correctIndex": 0,
              "explanation": "The day is stated.",
            },
          },
        ],
      });
      final ai = SentenceBatchAi(provider: provider, config: _config);
      await expectLater(
        ai.propose(
          topic: SentenceTopic.dailyLife,
          style: SentenceStyle.written,
          level: SentenceLevel.beginner,
          glossLanguage: "en",
          count: 1,
          cancel: CancelToken(),
        ),
        throwsFormatException,
      );
      expect((await store.savedSentenceBatches()).single.id, "saved");
    },
  );

  for (final (width, scale) in [(320.0, 1.6), (1200.0, 1.0)]) {
    for (final contextMode in [false, true]) {
      testWidgets("practice spacing $width/$scale context=$contextMode", (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final kind = contextMode
            ? SentencePracticeKind.newContext
            : SentencePracticeKind.sentence;
        Widget page({SentenceBatch? batch}) => MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SentencePractice(
            key: ValueKey(batch),
            store: store,
            explanation: explanation,
            batchAi: SentenceBatchAi(provider: provider, config: _config),
            kind: kind,
            initialBatch: batch,
          ),
        );
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        final generate = find.widgetWithText(
          FilledButton,
          "Generate an AI batch",
        );
        final saved = find.widgetWithText(
          OutlinedButton,
          "Saved sentence batches",
        );
        expect(
          tester.getTopLeft(saved).dy - tester.getBottomLeft(generate).dy,
          greaterThanOrEqualTo(8),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          page(
            batch: SentenceBatch(
              [_card()],
              generatedBy: "test-model",
              kind: kind,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final source = find.text("AI-generated · test-model");
        expect(source, findsOneWidget);
        final sentence = find.text(_card().text);
        expect(
          tester.getTopLeft(sentence).dy - tester.getBottomLeft(source).dy,
          greaterThan(16),
        );
        final rating = find.text("How well did you understand it?");
        if (contextMode) {
          expect(rating, findsNothing);
          expect(find.text("Skip"), findsOneWidget);
          expect(find.text("When does it close?"), findsOneWidget);
        } else {
          await tester.ensureVisible(rating);
          await tester.pumpAndSettle();
          final unclear = find.widgetWithText(OutlinedButton, "Not yet clear");
          expect(
            tester.getTopLeft(unclear).dy - tester.getBottomLeft(rating).dy,
            greaterThanOrEqualTo(8),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (width, scale) in [(320.0, 1.6), (1200.0, 1.0)]) {
    testWidgets(
      "training adjustment is not shown as confirmed mastery at $width",
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final profile = LanguageProfile(
          language: "en",
          exam: ExamProfile.zhejiang2026,
          due: 0,
          evidence: [
            for (var i = 0; i < 3; i++)
              LanguageObservation(
                id: "new-$i",
                skill: LanguageSkill.detail,
                kind: EvidenceKind.independent,
                verified: false,
                correct: true,
                level: SentenceLevel.beginner,
                at: DateTime.now().subtract(Duration(minutes: i)),
                basis: "item $i",
              ),
          ],
        );
        final plan = sentencePlan(
          profile,
          recommendLanguage(
            profile,
            LanguageGoal.communication,
            restrictTo: {LanguageSkill.detail},
          ),
          [],
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SentencePractice(
              store: store,
              explanation: explanation,
              batchAi: SentenceBatchAi(provider: provider, config: _config),
              recommendation: plan,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            "Based on recent unaided answers; mastery is not yet confirmed.",
          ),
          findsOneWidget,
        );
        expect(find.text("Intermediate"), findsOneWidget);
        expect(find.text("Prepare recommended practice"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (width, scale) in [(320.0, 1.6), (1200.0, 1.0)]) {
    testWidgets(
      "preview hides help and locks selection during regeneration at $width",
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        const sentence = "She caught the last bus home.";
        const hint = "Notice which bus she caught.";
        const translation = "She went home on the final bus.";
        provider.response = jsonEncode({
          "language": "en",
          "sentences": [
            {
              "text": sentence,
              "hint": hint,
              "translation": translation,
              "level": "beginner",
              "skill": "detail",
              "check": {
                "question": "Which bus did she catch?",
                "choices": ["The last bus", "The first bus", "A school bus"],
                "correctIndex": 0,
                "explanation": "The sentence says 'last'.",
              },
            },
            {
              "text": "The bus dropped her off outside her house.",
              "hint": "Notice the stop.",
              "translation": "She got off in front of her home.",
              "level": "beginner",
            },
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SentencePractice(
              store: store,
              explanation: explanation,
              batchAi: SentenceBatchAi(provider: provider, config: _config),
            ),
          ),
        );
        await tester.tap(find.text("Generate an AI batch"));
        await tester.pumpAndSettle();
        await tester.tap(find.text("Generate preview"));
        await tester.pumpAndSettle();
        final card = find.widgetWithText(CheckboxListTile, sentence);
        final save = find.widgetWithText(
          FilledButton,
          "Save selected and practise",
        );
        expect(card, findsOneWidget);
        expect(find.textContaining(hint), findsNothing);
        expect(find.textContaining(translation), findsNothing);
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(card).value, isFalse);

        final regenerating = Completer<void>();
        provider.pause = regenerating.future;
        provider.complete = false;
        await tester.tap(find.widgetWithText(TextButton, "Regenerate"));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(tester.widget<CheckboxListTile>(card).onChanged, isNull);

        regenerating.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining("Could not generate"), findsOneWidget);
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        expect(tester.widget<CheckboxListTile>(card).onChanged, isNotNull);
        expect(tester.widget<CheckboxListTile>(card).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    "sentence understanding generates from an empty library and reopens offline",
    (tester) async {
      const kept = "The shop opens at ten.";
      const skipped = "My sister walks to work.";
      provider.response =
          '''
{
  "language": "en",
  "sentences": [
    {"text":"$kept","hint":"Look for a time.","translation":"It opens at 10.","level":"beginner"},
    {"text":"$skipped","hint":"Look for how she travels.","translation":"She goes on foot.","level":"beginner"}
  ]
}
''';
      provider.complete = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SentencePractice(
            store: store,
            explanation: explanation,
            batchAi: SentenceBatchAi(provider: provider, config: _config),
          ),
        ),
      );

      Future<void> tap(String text) async {
        final label = find.text(text).last;
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(label);
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await tester.pumpAndSettle();
      }

      expect(find.text("Start offline batch"), findsNothing);
      expect(find.text("Saved sentence batches"), findsOneWidget);
      await tester.runAsync(() async {
        expect(await store.cards(language: "en"), isEmpty);
        expect(await store.savedSentenceBatches(), isEmpty);
      });
      await tap("Generate an AI batch");
      expect(provider.calls, 0);
      await tap("Generate preview");
      expect(find.text("Save selected and practise"), findsNothing);
      expect(
        find.text(
          "Could not generate a usable batch. Try again or open a saved batch.",
        ),
        findsOneWidget,
      );

      provider.complete = true;
      await tap("Generate preview");
      final request = jsonDecode(provider.lastRequest!.messages.single.text);
      expect(request, isNot(contains("targets")));
      expect(find.text(kept), findsOneWidget);
      expect(find.text(skipped), findsOneWidget);
      await tester.runAsync(() async {
        expect(await store.savedSentenceBatches(), isEmpty);
      });

      await tap(skipped);
      await tester.runAsync(() async {
        await tester.tap(find.text("Save selected and practise"));
        await store.whenIdle;
      });
      await tester.pumpAndSettle();
      expect(find.text(kept), findsOneWidget);
      expect(find.text("Try a comprehension check"), findsNothing);
      expect(find.text("AI-generated · test-model"), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text("Understood"));
        await store.whenIdle;
        final saved = (await store.savedSentenceBatches()).single;
        expect(openSavedSentenceBatch(saved).cards.single.text, kept);
        expect(
          (await store.sentenceEvidence("en").first).single.correct,
          isNull,
        );
        expect(await db.select(db.chatMessages).get(), isEmpty);
      });
      await tester.pumpAndSettle();

      provider.offline = true;
      await tap("Set up another batch");
      final saved = find.text("Saved sentence batches");
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(saved);
        await tester.pump();
        await store.savedSentenceBatches();
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async => tester.tap(find.text(kept)));
      await tester.pumpAndSettle();
      expect(find.text(kept), findsOneWidget);
      expect(find.text(skipped), findsNothing);
      expect(provider.calls, 2);
    },
  );

  testWidgets("context generation uses the selected group and both senses", (
    tester,
  ) async {
    late List<LanguageCard> senses;
    await tester.runAsync(() async {
      await store.saveEntries(
        language: "en",
        groupTitle: "Unrelated",
        groupType: VocabularyGroupType.topic,
        entries: const [VocabularyEntry(form: "ticket", meaning: "车票")],
      );
      await store.saveEntries(
        language: "en",
        groupTitle: "Two senses",
        groupType: VocabularyGroupType.topic,
        entries: const [
          VocabularyEntry(form: "station", meaning: "车站"),
          VocabularyEntry(form: "station", meaning: "广播电台"),
        ],
      );
      final group = (await store.groupNamed("en", "Two senses"))!;
      senses = await store.contextTargets(groupId: group.id, limit: 2);
    });
    expect(
      senses.map((card) => card.sense.meaning),
      unorderedEquals(["车站", "广播电台"]),
    );
    provider.response = jsonEncode({
      "language": "en",
      "sentences": [
        for (final (i, card) in senses.indexed)
          {
            "targetIndex": i,
            "text": card.sense.meaning == "车站"
                ? "At the station, commuters waited beside the tracks."
                : "The station aired our interview on its morning show.",
            "hint": "What happens in this scene?",
            "translation": "Look at how station is used.",
            "level": "beginner",
            "skill": "meaningInContext",
            "check": {
              "question": "What does station refer to here?",
              "choices": ["A rail stop", "A broadcaster", "A military post"],
              "correctIndex": card.sense.meaning == "车站" ? 0 : 1,
              "explanation": "Which activities are described?",
            },
          },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale("en"),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SentencePractice(
          store: store,
          explanation: explanation,
          batchAi: SentenceBatchAi(provider: provider, config: _config),
          kind: SentencePracticeKind.newContext,
        ),
      ),
    );
    await tester.runAsync(() => store.groups("en").first);
    await tester.pumpAndSettle();
    await tester.tap(find.text("All English vocabulary"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Two senses"));
    await tester.pumpAndSettle();
    expect(find.text("Two senses"), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text("Generate an AI batch"));
      await store.contextTargets(limit: 1);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text("Generate preview"));
    await tester.pumpAndSettle();
    final request = jsonDecode(provider.lastRequest!.messages.single.text);
    expect(request["targets"], [
      for (final (i, card) in senses.indexed)
        {"targetIndex": i, "form": "station", "meaning": card.sense.meaning},
    ]);
    expect(provider.calls, 1);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.runAsync(() async {
      await tester.tap(find.text("Save selected and practise"));
      await store.whenIdle;
      final history = await store.savedSentenceBatches(
        kind: SentencePracticeKind.newContext,
      );
      expect(
        openSavedSentenceBatch(history.single).cards
            .map((card) => (card.target!.senseId, card.target!.meaning)),
        senses.map((card) => (card.sense.id, card.sense.meaning)),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text("What does station refer to here?"), findsOneWidget);
  });

  testWidgets(
    "offline context history stays reachable and checks persist before continuing",
    (tester) async {
      const target = (senseId: "station-rail", form: "station", meaning: "车站");
      SentenceCard contextCard(String id, String text) => SentenceCard(
        id: id,
        text: text,
        question: "What is meant by station?",
        hint: "Notice the platform.",
        translation: "车站",
        checkExplanation: "The next train stops here.",
        level: SentenceLevel.beginner,
        skill: SentenceSkill.meaningInContext,
        choices: const ["A train stop", "A radio broadcaster"],
        correctIndex: 0,
        target: target,
      );
      final first = contextCard(
        "first",
        "They met at the station by platform two.",
      );
      final second = contextCard(
        "second",
        "His train left the station before sunrise.",
      );
      Future<void> save(
        String id,
        SentencePracticeKind kind,
        List<SentenceCard> cards,
      ) => store.saveSentenceBatch(
        SentenceBatchProposal(
          id: id,
          topic: SentenceTopic.travel,
          style: SentenceStyle.written,
          glossLanguage: "en",
          model: "test-model",
          promptVersion: 4,
          isMock: false,
          generatedAt: DateTime.utc(
            2025,
            1,
            kind == SentencePracticeKind.newContext ? 1 : 2,
          ),
          kind: kind,
          cards: cards,
        ),
        cards.map((card) => card.id).toSet(),
      );
      provider.offline = true;
      await tester.runAsync(() async {
        await save("older-context", SentencePracticeKind.newContext, [
          first,
          second,
        ]);
        for (var i = 0; i < 41; i++) {
          // Skill alone cannot make an ordinary or quick lookup sentence a new context.
          final id = i == 0 ? "quick:station" : "ordinary:$i";
          await save(id, SentencePracticeKind.sentence, [
            contextCard(id, "Unrelated station example $i."),
          ]);
        }
        expect(await store.savedSentenceBatches(), hasLength(41));
        final contexts = await store.savedSentenceBatches(
          kind: SentencePracticeKind.newContext,
        );
        expect(
          openSavedSentenceBatch(contexts.single).cards.first.target,
          target,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SentencePractice(
            store: store,
            explanation: explanation,
            kind: SentencePracticeKind.newContext,
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text("Saved sentence batches"));
        await tester.pump();
        await store.savedSentenceBatches(kind: SentencePracticeKind.newContext);
      });
      await tester.pumpAndSettle();
      expect(find.textContaining("Unrelated station"), findsNothing);
      expect(find.text(first.text), findsOneWidget);
      await tester.runAsync(() async => tester.tap(find.text(first.text)));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text("What is meant by station?"), findsOneWidget);
      expect(find.text("How well did you understand it?"), findsNothing);
      expect(find.text(first.checkExplanation), findsNothing);

      Future<void> tapVisible(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tapVisible("Show a hint");
      await tapVisible("A train stop");
      await tester.runAsync(() async {
        await tester.tap(find.text("Check answer"));
        await store.whenIdle;
        final attempt = await db
            .select(db.learningSentenceAttempts)
            .getSingle();
        expect(attempt.targetSenseId, target.senseId);
        expect(attempt.correct, isTrue);
        expect(attempt.helpBeforeAnswer, SentenceHelp.hint.flag);
        expect(attempt.rating, isNull);
      });
      await tester.pumpAndSettle();
      expect(find.text(first.checkExplanation), findsOneWidget);
      await tapVisible("Continue");
      expect(find.text(second.text), findsOneWidget);
      await tapVisible("A radio broadcaster");
      await tapVisible("Skip");
      expect(find.text("Skipped: 1"), findsOneWidget);
      expect(find.text("With help: 1/1 correct"), findsOneWidget);
      expect(find.textContaining("Self-rated"), findsNothing);
      await tester.runAsync(() async {
        expect(
          await db.select(db.learningSentenceAttempts).get(),
          hasLength(1),
        );
      });
      expect(provider.calls, 0);
    },
  );

  testWidgets(
    "offline sentence check separates helped answers and self-rating",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SentencePractice(
            store: store,
            explanation: explanation,
            initialBatch: SentenceBatch([_card()]),
          ),
        ),
      );
      expect(find.text(_card().text), findsOneWidget);
      expect(find.text("At noon"), findsNothing);
      expect(
        find.text(
          "“Rather than” contrasts the actual closing time with a different one.",
        ),
        findsNothing,
      );

      await tester.tap(find.text("Show a hint"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Try a comprehension check"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("At noon"));
      await tester.pumpAndSettle();
      expect(find.text("Correct"), findsNothing);
      await tester.tap(find.text("Check answer"));
      await tester.pumpAndSettle();
      expect(find.text("Correct"), findsOneWidget);

      final finish = find.widgetWithText(OutlinedButton, "Understood");
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(finish);
        await store.whenIdle;
      });
      await tester.pumpAndSettle();
      expect(find.text("With help: 1/1 correct"), findsOneWidget);
      expect(find.text("Self-rated as understood: 1/1"), findsOneWidget);
      expect(provider.calls, 0);

      await tester.runAsync(() async {
        final attempt = await db
            .select(db.learningSentenceAttempts)
            .getSingle();
        expect(attempt.correct, true);
        expect(attempt.helpBeforeAnswer, SentenceHelp.hint.flag);
        expect(attempt.rating, SentenceRating.understood.name);
      });
    },
  );
}
