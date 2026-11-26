import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/prompt_settings.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/lexical_form_store.dart";
import "package:tixun/features/language_learning/vocabulary_ai.dart";
import "package:tixun/features/language_learning/vocabulary_proposal_dialog.dart";

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

class _VocabularyProvider implements ChatProvider {
  _VocabularyProvider({required this.completed});

  final bool completed;
  bool duplicate = false;
  String? response;
  int requests = 0;
  late Map parameters;
  late String instructions;

  @override
  AiConversation start(
    ProviderConfig config, {
    String? apiKeyOverride,
  }) => AiConversation((request, cancel) async* {
    expect(
      encodeCompletion(config, request).containsKey("max_tokens"),
      isFalse,
    );
    requests++;
    instructions = request.instructions;
    parameters = jsonDecode(request.messages.single.text) as Map;
    yield AiChunk(
      completed: completed,
      text:
          response ??
          '{"language":"en","groupTitle":" Station English ","entries":['
              '{"form":"platform","type":"word","meaning":"a boarding area",'
              '"partOfSpeech":"n.","example":"The train leaves from platform two.",'
              '"translation":"We board at platform two.",'
              '"application":"Please wait on the ___ until the doors open.",'
              '"applicationAnswer":"platform","forms":[{"surface":"platforms","inflection":"plural"}]},'
              '{"form":"${duplicate ? "platform" : "ticket"}","type":"word","meaning":"a pass for a journey",'
              '"partOfSpeech":"n.","example":"I bought a ticket at the station.",'
              '"translation":"I paid for my trip at the station."}]}',
    );
  });
}

class _ChunkProvider implements ChatProvider {
  final counts = <int>[];
  bool interruptSecond = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        expect(
          encodeCompletion(config, request).containsKey("max_tokens"),
          isFalse,
        );
        final data = jsonDecode(request.messages.single.text) as Map;
        final count = data["count"] as int;
        counts.add(count);
        expect(request.tools, isEmpty);
        expect(request.instructions, contains("Do not create cloze exercises"));
        yield AiChunk(
          completed: !interruptSecond || counts.length == 1,
          text: jsonEncode({
            "language": "en",
            "entries": [
              for (var i = 0; i < count; i++)
                {
                  "form": "expression ${counts.length} $i",
                  "type": "phrase",
                  "meaning": "One meaning.",
                  "example": "We rehearsed in the morning.",
                  "translation": "We practised early.",
                  "application": "Please try ___ another time.",
                  "applicationAnswer": "expression ${counts.length} $i",
                },
            ],
          }),
        );
      });
}

Future<void> _openProposal(
  WidgetTester tester,
  LanguageLearningStore store,
  _VocabularyProvider provider, {
  String? title,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale("en"),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showVocabularyProposal(
              context,
              store: store,
              ai: VocabularyAi(provider),
              config: _config,
            ),
            child: const Text("Open"),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("Open"));
  await tester.pumpAndSettle();
  expect(provider.requests, 0);
  if (title != null) {
    await tester.enterText(find.byType(TextFormField), title);
  }
  await tester.tap(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(
      find.widgetWithText(FilledButton, "Add vocabulary with AI"),
    );
  });
  await tester.pump();
  for (
    var i = 0;
    i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  testWidgets(
    "AI preview excludes normalized trash matches from another group",
    (tester) async {
      final provider = _VocabularyProvider(completed: true)
        ..response = jsonEncode({
          "language": "en",
          "entries": [
            {
              "form": " PLATform ",
              "type": "word",
              "partOfSpeech": "n.",
              "meaning": "a stage",
              "example": "She stepped onto the platform.",
              "translation": "She went up onto the stage.",
            },
            {
              "form": "ticket",
              "type": "word",
              "partOfSpeech": "n.",
              "meaning": "a pass for a journey",
              "example": "I bought a ticket.",
              "translation": "I paid the fare.",
            },
          ],
        });
      await tester.runAsync(() async {
        await store.saveEntries(
          language: "en",
          groupTitle: "Travel",
          groupType: VocabularyGroupType.topic,
          entries: const [
            VocabularyEntry(form: "platform", meaning: "boarding area"),
          ],
        );
        final card = (await store.cards(language: "en")).single;
        await store.moveToTrash([card.sense.id]);
      });
      await _openProposal(tester, store, provider, title: "Station");
      expect(find.text("ticket — a pass for a journey"), findsOneWidget);
      expect(
        find.textContaining(RegExp("platform", caseSensitive: false)),
        findsNothing,
      );
      expect(provider.parameters["exclude"], isEmpty);
    },
  );

  for (final level in VocabularyLevel.values) {
    test(
      "new $level vocabulary prioritizes usefulness even with custom preferences",
      () async {
        final provider = _VocabularyProvider(completed: true);
        final proposal =
            await VocabularyAi(
              provider,
              prompts: PromptSettings().update(
                "language_vocabulary",
                "Use concise definitions.",
              ),
            ).propose(
              config: _config,
              topic: "Work",
              groupType: VocabularyGroupType.topic,
              level: level,
              glossLanguage: "en",
              existingExpressions: const [],
              cancel: CancelToken(),
              count: 2,
            );
        expect(provider.parameters["level"], level.name);
        expect(provider.instructions, contains("At every level, prioritize"));
        expect(
          provider.instructions,
          contains("Difficulty must not mean rarity"),
        );
        expect(provider.instructions, contains("beginner:"));
        expect(provider.instructions, contains("intermediate:"));
        expect(provider.instructions, contains("advanced:"));
        expect(
          provider.instructions,
          contains("Unless the supplied topic explicitly requires them"),
        );
        expect(
          provider.instructions,
          contains("Do not invent frequency ranks"),
        );
        expect(provider.instructions, contains("Use concise definitions."));
        expect(proposal.entries, hasLength(2));
        expect(await store.cards(language: "en"), isEmpty);
      },
    );
  }

  test("expansion filters the full group and paraphrased duplicates within one response", () async {
    await store.saveEntries(
      language: "en",
      groupTitle: "Large group",
      groupType: VocabularyGroupType.topic,
      entries: [
        for (var i = 0; i < 35; i++)
          VocabularyEntry(form: "word$i", meaning: "Meaning $i"),
        const VocabularyEntry(form: "platform", meaning: "A place to board"),
      ],
    );
    final group = (await store.groupNamed("en", "Large group"))!;
    final existing = await store.groupExpressions(group.id);
    expect(existing, hasLength(36));
    Future<VocabularyProposal> propose(
      _VocabularyProvider provider,
      List<String> exclusions,
    ) => VocabularyAi(provider).propose(
      config: _config,
      topic: "Travel",
      groupType: VocabularyGroupType.topic,
      level: VocabularyLevel.beginner,
      glossLanguage: "en",
      existingExpressions: exclusions,
      cancel: CancelToken(),
    );
    final filtered = await propose(
      _VocabularyProvider(completed: true),
      existing,
    );
    expect(filtered.entries.map((e) => e.form), ["ticket"]);
    final repeated = await propose(
      _VocabularyProvider(completed: true)..duplicate = true,
      [],
    );
    expect(repeated.entries, hasLength(1));
    final crossGroup = await store.existingGroupsForEntries("en", [
      const VocabularyEntry(form: "platform", meaning: "A paraphrased meaning"),
    ]);
    expect(crossGroup.values.single, ["Large group"]);
  });

  test("large vocabulary proposals split requests and preview only complete chunks", () async {
    Future<VocabularyProposal> propose(_ChunkProvider provider) =>
        VocabularyAi(provider).propose(
          config: _config,
          topic: "Practice",
          groupType: VocabularyGroupType.topic,
          level: VocabularyLevel.beginner,
          glossLanguage: "en",
          existingExpressions: const [],
          cancel: CancelToken(),
          count: 10,
        );
    final provider = _ChunkProvider();
    final complete = await propose(provider);
    expect(provider.counts, [6, 4]);
    expect(complete.entries, hasLength(10));
    expect(complete.entries.first.application, contains("___"));
    final interrupted = _ChunkProvider()..interruptSecond = true;
    final partial = await propose(interrupted);
    expect(partial.requested, 10);
    expect(partial.entries, hasLength(6));
    expect(await store.cards(language: "en"), isEmpty);
  });

  test(
    "generated unchanged and periphrastic forms save with their senses",
    () async {
      final provider = _VocabularyProvider(completed: true)
        ..response = jsonEncode({
          "language": "en",
          "entries": [
            {
              "form": "cut",
              "type": "word",
              "partOfSpeech": "v.",
              "meaning": "divide with a blade",
              "example": "I cut the paper.",
              "translation": "I divided the paper.",
              "forms": [
                {"surface": "cut", "inflection": "past"},
                {"surface": "cut", "inflection": "pastParticiple"},
                {"surface": "CUT", "inflection": "past"},
              ],
            },
            {
              "form": "useful",
              "type": "word",
              "partOfSpeech": "adj.",
              "meaning": "helpful",
              "example": "This tool is useful.",
              "translation": "This tool helps.",
              "forms": [
                {"surface": "more useful", "inflection": "comparative"},
                {"surface": "most useful", "inflection": "superlative"},
              ],
            },
          ],
        });
      final proposal = await VocabularyAi(provider).propose(
        config: _config,
        topic: "Everyday",
        groupType: VocabularyGroupType.topic,
        level: VocabularyLevel.intermediate,
        glossLanguage: "en",
        existingExpressions: const [],
        cancel: CancelToken(),
        count: 2,
      );
      expect(provider.requests, 1);
      expect(proposal.entries.first.forms, hasLength(2));
      expect(await store.cards(language: "en"), isEmpty);
      await store.saveEntries(
        language: "en",
        groupTitle: "Everyday",
        groupType: VocabularyGroupType.topic,
        entries: proposal.entries,
        provenance: proposal.provenance,
      );
      final cards = await store.cards(language: "en");
      final cut = cards.singleWhere((card) => card.item.form == "cut");
      final useful = cards.singleWhere((card) => card.item.form == "useful");
      expect(
        (await store.lexicalForms(cut.sense.id))
            .map((f) => f.inflection)
            .toSet(),
        {"past", "pastParticiple"},
      );
      expect(
        (await store.lexicalForms(useful.sense.id))
            .map((f) => f.surface)
            .toSet(),
        {"more useful", "most useful"},
      );
      final exercises = await store.formPractice("en");
      final comparative = exercises.singleWhere(
        (e) => e.form.surface == "more useful",
      );
      expect(
        await store.recordFormPractice(
          attemptId: "spaced",
          exercise: comparative,
          answer: " MORE   USEFUL ",
          production: true,
        ),
        isTrue,
      );
    },
  );

  for (final forms in [
    [
      {"surface": "cuts", "inflection": "unknown"},
    ],
    [
      {"surface": "", "inflection": "plural"},
    ],
    [
      {"surface": "cuts", "inflection": 1},
    ],
    "cuts",
  ]) {
    test("rejects malformed generated forms: $forms", () async {
      final provider = _VocabularyProvider(completed: true)
        ..response = jsonEncode({
          "language": "en",
          "entries": [
            {
              "form": "cut",
              "type": "word",
              "meaning": "an incision",
              "example": "It is a small cut.",
              "translation": "A small incision.",
              "forms": forms,
            },
          ],
        });
      await expectLater(
        VocabularyAi(provider).propose(
          config: _config,
          topic: "Everyday",
          groupType: VocabularyGroupType.topic,
          level: VocabularyLevel.intermediate,
          glossLanguage: "en",
          existingExpressions: const [],
          cancel: CancelToken(),
          count: 1,
        ),
        throwsFormatException,
      );
      expect(await store.cards(language: "en"), isEmpty);
      expect(provider.requests, 1);
    });
  }

  testWidgets("preview saves only selected candidates and creates no Chat", (
    tester,
  ) async {
    final provider = _VocabularyProvider(completed: true);
    await _openProposal(tester, store, provider);
    expect(find.text("Review vocabulary candidates"), findsOneWidget);
    expect(provider.requests, 1);
    expect(provider.parameters["generateGroupTitle"], isTrue);
    expect(provider.parameters, isNot(contains("topic")));
    expect(find.text("Station English"), findsOneWidget);
    await tester.runAsync(() async {
      expect(await store.cards(language: "en"), isEmpty);
    });

    await tester.ensureVisible(find.text("ticket — a pass for a journey"));
    await tester.tap(find.text("ticket — a pass for a journey"));
    await tester.pump();
    final edit = find.byTooltip("Edit").first;
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      "a place to board",
    );
    final confirm = find.widgetWithText(FilledButton, "Confirm");
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(confirm);
      await tester.pump();
      await store.existingGroupsForEntries("en", const [
        VocabularyEntry(form: "platform", meaning: "a place to board"),
      ]);
    });
    await tester.pumpAndSettle();
    expect(find.text("platform — a place to board"), findsOneWidget);
    expect(find.text("n."), findsNWidgets(2));
    await tester.runAsync(() async {
      await tester.tap(find.text("Save selected expressions"));
      await store.whenIdle;
    });
    await tester.pumpAndSettle();
    expect(find.text("Review vocabulary candidates"), findsNothing);
    await tester.runAsync(() async {
      final saved = (await store.cards(language: "en")).single;
      final groups = await db.select(db.learningVocabularyGroups).get();
      expect(groups.single.title, "Station English");
      expect(saved.item.form, "platform");
      expect(saved.sense.meaning, "a place to board");
      expect(saved.sense.partOfSpeech, "n.");
      expect(
        (await store.lexicalForms(saved.sense.id)).single.surface,
        "platforms",
      );
      expect(saved.sense.aiModel, _config.model);
      expect(
        saved.sense.application,
        "Please wait on the ___ until the doors open.",
      );
      expect(saved.sense.applicationAnswer, "platform");
      expect(await db.select(db.chatMessages).get(), isEmpty);
    });
  });

  testWidgets("a supplied name takes precedence over the model's title", (
    tester,
  ) async {
    final provider = _VocabularyProvider(completed: true);
    await _openProposal(tester, store, provider, title: "Rail travel");
    expect(provider.parameters["topic"], "Rail travel");
    expect(provider.parameters, isNot(contains("generateGroupTitle")));
    expect(find.text("Rail travel"), findsOneWidget);
    expect(find.text("Station English"), findsNothing);
  });

  testWidgets("an interrupted reply cannot become a saveable preview", (
    tester,
  ) async {
    await _openProposal(tester, store, _VocabularyProvider(completed: false));
    expect(
      find.text(
        "Could not generate a complete vocabulary list. No expressions were saved.",
      ),
      findsOneWidget,
    );
    expect(find.text("Save selected expressions"), findsNothing);
    await tester.runAsync(() async {
      expect(await store.cards(language: "en"), isEmpty);
    });
  });
}
