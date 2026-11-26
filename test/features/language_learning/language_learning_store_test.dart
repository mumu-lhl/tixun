import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/language_store.dart";

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  final start = DateTime.now().subtract(const Duration(minutes: 5));

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
  });

  Future<void> save(String group, VocabularyEntry entry) => store.saveEntries(
    language: "en",
    groupTitle: group,
    groupType: VocabularyGroupType.topic,
    entries: [entry],
    now: start,
  );

  test(
    "immediate recall retries cannot postpone a delayed retention check",
    () async {
      final start = DateTime(2026, 1, 1);
      await save("Recall", const VocabularyEntry(form: "run", meaning: "move"));
      final card = (await store.cards(language: "en")).single;
      Future<void> recall(String id, RecallRating rating, DateTime time) =>
          store.recordRecall(
            attemptId: id,
            senseId: card.sense.id,
            rating: rating,
            groupPrompt: false,
            now: time,
          );
      Future<LearningReviewSchedule> schedule() =>
          db.select(db.learningReviewSchedules).getSingle();

      await recall("forgot", RecallRating.again, start);
      final due = start.add(const Duration(days: 1));
      expect((await schedule()).dueAt, due);
      await recall(
        "retry",
        RecallRating.easy,
        start.add(const Duration(minutes: 10)),
      );
      expect((await schedule()).intervalDays, 1);
      expect((await schedule()).dueAt, due);
      await recall(
        "retry",
        RecallRating.easy,
        start.add(const Duration(minutes: 20)),
      );
      expect((await schedule()).repetitions, 1);
      await recall(
        "delayed",
        RecallRating.good,
        start.add(const Duration(days: 2)),
      );
      expect((await schedule()).intervalDays, 3);
      expect((await schedule()).dueAt, start.add(const Duration(days: 5)));
      final evidence = await store.recentEvidence("en").first;
      expect(evidence, hasLength(3));
      expect(evidence.every((row) => row.correct == null), isTrue);
    },
  );

  test(
    "sharing and deleting groups preserve sense-level review and evidence",
    () async {
      await save(
        "Exercise",
        const VocabularyEntry(form: "run", meaning: "move quickly on foot"),
      );
      final first = (await store.cards(language: "en")).single;
      await store.recordRecall(
        attemptId: "recall-1",
        senseId: first.sense.id,
        rating: RecallRating.good,
        groupPrompt: true,
        now: start,
      );
      await save(
        "Morning",
        const VocabularyEntry(form: " Run ", meaning: "move quickly on foot"),
      );
      await save(
        "Business",
        const VocabularyEntry(form: "run", meaning: "manage"),
      );

      final groups = await store.groups("en").first;
      final exercise = groups.singleWhere((group) => group.title == "Exercise");
      final morning = groups.singleWhere((group) => group.title == "Morning");
      await store.deleteGroup(exercise.id);

      expect((await store.groups("en").first).map((row) => row.title), [
        "Business",
        "Morning",
      ]);
      expect(await store.cards(language: "en", groupId: exercise.id), isEmpty);
      expect((await store.recentEvidence("en").first).single.id, "recall-1");
      final shared = (await store.cards(
        language: "en",
        groupId: morning.id,
      )).single;
      final dueAt = start.add(const Duration(days: 3));
      final ready = (await store.cards(
        language: "en",
        dueBefore: dueAt,
      )).single;
      expect(shared.sense.id, first.sense.id);
      expect(ready.item.id, first.item.id);
      expect(ready.sense.meaning, first.sense.meaning);
      expect(await store.dueCount("en", now: dueAt).first, 1);
      expect(
        (await store.cards(language: "en")).map((c) => c.sense.meaning),
        contains("manage"),
      );
      expect(await store.cards(language: "fr"), isEmpty);
    },
  );

  test(
    "context matches and recall self-ratings remain separate evidence",
    () async {
      await save(
        "Kitchen",
        const VocabularyEntry(
          form: "stir",
          meaning: "mix by moving a spoon",
          example: "She stirred the soup slowly.",
          application: "Please ___ the coffee before drinking it.",
          applicationAnswer: "stir",
        ),
      );
      await save(
        "Kitchen",
        const VocabularyEntry(form: "spoon", meaning: "a utensil"),
      );
      final card = (await store.cards(
        language: "en",
        contextsOnly: true,
      )).single;
      await store.recordApplication(
        attemptId: "context-1",
        senseId: card.sense.id,
        answer: " STIR ",
        usedHelp: false,
        groupPrompt: false,
      );
      await store.recordApplication(
        attemptId: "context-2",
        senseId: card.sense.id,
        answer: "stirred",
        usedHelp: false,
        groupPrompt: false,
      );
      expect(await store.cards(language: "en", dueBefore: start), isEmpty);
      await store.recordRecall(
        attemptId: "recall-1",
        senseId: card.sense.id,
        rating: RecallRating.hard,
        groupPrompt: true,
        now: start,
      );

      final evidence = {
        for (final row in await store.recentEvidence("en").first) row.id: row,
      };
      expect(evidence["context-1"]!.correct, isTrue);
      expect(evidence["context-1"]!.rating, isNull);
      expect(evidence["context-2"]!.correct, isFalse);
      expect(evidence["recall-1"]!.correct, isNull);
      expect(evidence["recall-1"]!.rating, RecallRating.hard.name);
      expect(evidence["recall-1"]!.groupPrompt, isTrue);
    },
  );
}
