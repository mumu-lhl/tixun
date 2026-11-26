import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_content.dart";
import "package:tixun/features/language_learning/sentence_store.dart";

import "../../support/quick_lookup.dart" show quickTestConfig;

class ContextProvider implements ChatProvider {
  String scene =
      "Before boarding, Maya asked the station staff which platform to use.";
  String question = "What does station refer to in this scene?";
  int targetIndex = 0;
  String? instructions;
  Map? input;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        instructions = request.instructions;
        input = jsonDecode(request.messages.single.text) as Map;
        yield AiChunk(
          completed: true,
          text: jsonEncode({
            "language": "en",
            "sentences": [
              {
                "targetIndex": targetIndex,
                "text": scene,
                "hint": "Notice boarding and platform.",
                "translation": "上车前，玛雅向车站工作人员询问站台。",
                "level": "beginner",
                "skill": "meaningInContext",
                "check": {
                  "question": question,
                  "choices": [
                    "A railway stopping place",
                    "A radio company",
                    "A social position",
                  ],
                  "correctIndex": 0,
                  "explanation": "Boarding and platform locate the scene at a railway station.",
                },
              },
            ],
          }),
        );
      });
}

void main() {
  test("new contexts ask for interpretations, reject saved examples and reject blanks", () async {
    final db = AppDatabase.memory();
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await store.saveEntries(
      language: "en",
      groupTitle: "Travel",
      groupType: VocabularyGroupType.topic,
      entries: const [
        VocabularyEntry(
          form: "station",
          meaning: "车站",
          example: "The station is busy.",
        ),
      ],
    );
    final words = await store.cards(language: "en");
    final provider = ContextProvider();
    final ai = SentenceBatchAi(provider: provider, config: quickTestConfig);
    Future<void> generate() async {
      final proposal = await ai.propose(
        topic: SentenceTopic.travel,
        style: SentenceStyle.written,
        level: SentenceLevel.beginner,
        glossLanguage: "zh",
        count: 1,
        cancel: CancelToken(),
        kind: SentencePracticeKind.newContext,
        vocabulary: words,
      );
      expect(proposal.cards.single.target, (
        senseId: words.single.sense.id,
        form: "station",
        meaning: "车站",
      ));
      expect(proposal.cards.single.choices, hasLength(3));
      expect(proposal.cards.single.text, isNot(contains("___")));
      expect(provider.input!["targets"], [
        {"targetIndex": 0, "form": "station", "meaning": "车站"},
      ]);
      expect(
        provider.instructions,
        contains("Never ask the learner to complete"),
      );
    }

    await generate();
    provider.scene = "The station is busy!";
    await expectLater(generate(), throwsFormatException);
    provider.scene = "Before boarding, Maya asked the ___ staff.";
    await expectLater(generate(), throwsFormatException);
    provider.scene = "Before boarding, Maya asked the railway staff.";
    await expectLater(generate(), throwsFormatException);
    provider.scene = "Before boarding, Maya asked the station staff.";
    provider.targetIndex = 1;
    await expectLater(generate(), throwsFormatException);
    provider.targetIndex = 0;
    provider.question = "Where is Maya going?";
    await expectLater(generate(), throwsFormatException);
    provider.question = "这里station指什么？";
    await generate();
  });

  test(
    "context targets rotate by answered sense within active English vocabulary",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });

      Future<void> save(
        String group,
        List<VocabularyEntry> entries, {
        String language = "en",
      }) => store.saveEntries(
        language: language,
        groupTitle: group,
        groupType: VocabularyGroupType.topic,
        entries: entries,
      );
      await save("Travel", const [
        VocabularyEntry(form: "station", meaning: "车站"),
        VocabularyEntry(form: "ticket", meaning: "车票"),
      ]);
      await save("Broadcast", const [
        VocabularyEntry(form: "station", meaning: "电台"),
      ]);
      await save("French", const [
        VocabularyEntry(form: "gare", meaning: "车站"),
      ], language: "fr");

      final travel = (await store.groupNamed("en", "Travel"))!;
      final group = await store.contextTargets(groupId: travel.id, limit: 20);
      final first = group.first;
      final last = group.last;
      expect(
        group.map((card) => card.sense.meaning),
        unorderedEquals(["车站", "车票"]),
      );
      await store.recordSentence(
        batchId: "test",
        card: SentenceCard(
          id: "question",
          text: "Context question using ${first.item.form}",
          question: "What is meant here?",
          translation: "",
          hint: "",
          level: SentenceLevel.beginner,
          skill: SentenceSkill.meaningInContext,
          choices: const ["One", "Two"],
          correctIndex: 0,
          target: (
            senseId: first.sense.id,
            form: first.item.form,
            meaning: first.sense.meaning,
          ),
        ),
        selectedIndex: 1,
        helpUsed: {},
      );
      expect(
        (await store.contextTargets(
          groupId: travel.id,
          limit: 1,
        )).single.sense.id,
        last.sense.id,
      );
      await store.moveToTrash([last.sense.id]);
      expect(
        (await store.contextTargets(limit: 3))
            .map((card) => card.sense.meaning),
        ["电台", first.sense.meaning],
      );
    },
  );
}
