import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/course_progress.dart";
import "package:tixun/features/language_learning/language_profile_store.dart";
import "package:tixun/features/language_learning/language_skills.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_batch_store.dart";
import "package:tixun/features/language_learning/sentence_content.dart";
import "package:tixun/features/language_learning/sentence_store.dart";

import "support/quick_lookup.dart";

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

  test(
    "course completion needs two distinct checks and carries scoped evidence",
    () async {
      final now = DateTime(2026);
      Future<void> record(
        int rotation, {
        int recognized = 2,
        int produced = 1,
      }) => store.recordCourseCheck(
        language: "ja",
        lesson: 0,
        rotation: rotation,
        recognized: recognized,
        produced: produced,
        now: now,
      );
      Future<CourseProgress> read() async =>
          (await store.courseProgress("ja").first)[courseLessonId(0)]!;
      await record(0);
      await record(0);
      await record(1, produced: 0);
      expect((await read()).passed, false);
      expect((await read()).passedRotations, {0});
      await record(2);
      final progress = await read();
      expect(progress.passed, true);
      expect(progress.due(now.add(const Duration(days: 8))), true);
      expect(sameCourseExpression("あ い、う え お。", "あ、い、う、え、お"), true);
      expect(sameCourseExpression("アイウエオ", "あいうえお"), false);
      expect(
        (await store.readLanguageProfile("ja"))
            .skills[LanguageSkill.wordRecognition]!
            .independent,
        3,
      );
      expect(
        (await store.readLanguageProfile("en"))
            .skills[LanguageSkill.wordRecognition]!
            .independent,
        0,
      );
    },
  );

  test("a saved quick sentence gets exactly one validated revision and contributes evidence", () async {
    const original = SentenceCard.study(
      id: "quick:example",
      text: "I left before six.",
      translation: "我六点前走了。",
      hint: "",
      level: SentenceLevel.beginner,
    );
    await store.saveSentenceBatch(
      SentenceBatchProposal(
        id: original.id,
        topic: SentenceTopic.dailyLife,
        style: SentenceStyle.written,
        glossLanguage: "zh",
        model: "Fixture",
        promptVersion: 1,
        isMock: false,
        generatedAt: DateTime.now(),
        cards: const [original],
      ),
      {original.id},
    );
    final provider = QuickTestProvider()
      ..reply = (_) => Stream.value(
        const AiChunk(
          completed: true,
          text:
              '{"skill":"sequence","check":{"question":"When did the speaker leave?",'
              '"choices":["Before six","At six","After six"],"correctIndex":0,"explanation":"before six"}}',
        ),
      );
    final ai = SentenceBatchAi(provider: provider, config: quickTestConfig);
    final token = CancelToken();
    final candidate = await ai.checkSaved(
      original,
      glossLanguage: "zh",
      cancel: token,
    );
    expect(provider.requests, hasLength(1));
    expect(provider.requests.single.maxOutputTokens, isNull);
    final checked = await store.attachQuickSentenceCheck(candidate, token);
    expect(checked.revision, 2);
    expect(checked.text, original.text);
    final saved = openSavedSentenceBatch(
      (await store.savedSentenceBatches()).single,
    ).cards.single;
    expect(saved.choices, checked.choices);
    await store.recordSentence(
      batchId: "attempt",
      card: saved,
      rating: SentenceRating.understood,
      helpUsed: {},
      selectedIndex: 0,
    );
    final evidence = (await store.readLanguageProfile("en"))
        .skills[LanguageSkill.sequence]!;
    expect(evidence.tentative, 1);
    expect(evidence.independent, 0);
    expect(await db.select(db.chatMessages).get(), isEmpty);
  });
}
