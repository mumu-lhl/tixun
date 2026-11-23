import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_content.dart";

import "../../support/quick_lookup.dart" show quickTestConfig;

class ContextProvider implements ChatProvider {
  String scene =
      "Before boarding, Maya asked the station staff which platform to use.";
  String question = "What does station refer to in this scene?";
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
        focus: SentenceSkill.meaningInContext,
        vocabulary: words,
      );
      expect(proposal.cards.single.choices, hasLength(3));
      expect(proposal.cards.single.text, isNot(contains("___")));
      expect(provider.input!["vocabulary"], [
        {"form": "station", "meaning": "车站"},
      ]);
      expect(
        provider.instructions,
        contains("Never ask the learner to complete"),
      );
    }

    await generate();
    provider.scene = "The station is busy.";
    await expectLater(generate(), throwsFormatException);
    provider.scene = "Before boarding, Maya asked the ___ staff.";
    await expectLater(generate(), throwsFormatException);
  });
}
