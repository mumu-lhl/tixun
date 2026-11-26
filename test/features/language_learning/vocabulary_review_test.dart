import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/fsrs.dart";
import "package:tixun/features/language_learning/language_profile_store.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/vocabulary_review_settings.dart";

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  final start = DateTime.utc(2026, 1, 1);
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
    List<String> words, {
    String language = "en",
  }) => store.saveEntries(
    language: language,
    groupTitle: group,
    groupType: VocabularyGroupType.topic,
    now: start,
    entries: [
      for (final word in words)
        VocabularyEntry(form: word, meaning: "Meaning of $word"),
    ],
  );

  Future<void> rate(
    String id,
    LanguageCard card,
    RecallRating rating,
    DateTime now, {
    RecallKind kind = RecallKind.scheduled,
    DateTime? selectedAt,
    bool groupPrompt = false,
  }) => store.recordRecall(
    attemptId: id,
    senseId: card.sense.id,
    rating: rating,
    groupPrompt: groupPrompt,
    kind: kind,
    selectedAt: selectedAt,
    now: now,
  );

  test("the combined queue prioritizes due cards, covers three rounds and deduplicates shared senses", () async {
    await save("A", ["due-a", "shared", "new"]);
    await save("B", ["shared", "due-b", "future"]);
    await save("Deleted", ["orphan"]);
    await save("Foreign", ["étranger"], language: "fr");
    await store.deleteGroup((await store.groupNamed("en", "Deleted"))!.id);
    final groupA = (await store.groupNamed("en", "A"))!.id;
    final groupB = (await store.groupNamed("en", "B"))!.id;
    final cards = {
      for (final c in await store.cards(language: "en")) c.item.form: c,
    };
    final tomorrow = start.add(const Duration(days: 1));
    final twoDays = start.add(const Duration(days: 2));
    await rate("a", cards["due-a"]!, RecallRating.again, start);
    await rate("shared", cards["shared"]!, RecallRating.again, tomorrow);
    await rate("b", cards["due-b"]!, RecallRating.again, tomorrow);
    await rate("future", cards["future"]!, RecallRating.easy, start);
    final before = twoDays.subtract(const Duration(seconds: 1));
    expect(await store.dueCount("en", now: before).first, 1);
    expect(await store.dueCount("en", now: twoDays).first, 3);
    expect(
      await store.countDue("en", now: twoDays.add(const Duration(seconds: 1))),
      3,
    );
    expect((await store.readLanguageProfile("en", now: twoDays)).due, 3);
    expect(await store.cards(language: "en", dueBefore: twoDays), hasLength(3));
    final scopedA = await store.recallCards(
      language: "en",
      groupId: groupA,
      now: twoDays,
      limit: 10,
    );
    final scopedB = await store.recallCards(
      language: "en",
      groupId: groupB,
      now: twoDays,
      limit: 10,
    );
    expect(scopedA.map((card) => card.item.form), ["due-a", "shared", "new"]);
    expect(
      scopedB.any((card) => card.sense.id == cards["shared"]!.sense.id),
      isTrue,
    );
    final seen = <String>{};
    Future<List<LanguageCard>> next() => store.recallCards(
      language: "en",
      allGroups: true,
      seen: seen,
      now: twoDays,
      limit: 2,
    );
    final first = await next();
    expect(first.first.item.form, "due-a");
    seen.add(first.first.sense.id);
    await rate("advance", first.first, RecallRating.good, twoDays);
    final second = await next();
    expect(second.first.sense.id, first.last.sense.id);
    seen.add(second.first.sense.id); // Skip the current card without writing.
    final third = await next();
    expect(third.last.item.form, "new");
    expect(third.last.isNew, isTrue);
    expect(third.first.isNew, isFalse);
    seen.addAll(third.map((card) => card.sense.id));
    expect(await next(), isEmpty);
    expect(
      (await store.recallCards(
        language: "en",
        now: twoDays,
        allGroups: true,
        limit: 10,
      )).any((card) => card.sense.id == second.first.sense.id),
      isTrue,
    );
    final free = await store.recallCards(
      language: "en",
      now: twoDays,
      allGroups: true,
      practiceOnly: true,
      limit: 10,
    );
    expect(
      free.map((card) => card.item.form),
      unorderedEquals(["due-a", "shared", "new", "due-b", "future"]),
    );
  });

  test("formal ratings honor the latest settings while retries, free practice and stale attempts preserve schedules", () async {
    await save("A", ["word"]);
    final card = (await store.cards(language: "en")).single;
    Future<LearningReviewSchedule> schedule() =>
        db.select(db.learningReviewSchedules).getSingle();
    final initial = await schedule();
    expect(
      await loadVocabularyReviewSettings(db),
      defaultVocabularyReviewSettings,
    );
    final trial = (enabled: true, retentionPercent: 97, maximumInterval: 1);
    await saveVocabularyReviewSettings(db, trial);
    expect(await schedule(), initial);
    await rate(
      "practice",
      card,
      RecallRating.easy,
      start,
      kind: RecallKind.practice,
    );
    expect(await schedule(), initial);

    await Future.wait([
      rate("same", card, RecallRating.easy, start, groupPrompt: true),
      rate("same", card, RecallRating.easy, start, groupPrompt: true),
      rate("stale", card, RecallRating.easy, start, selectedAt: start),
    ]);
    final first = await schedule();
    expect(first.repetitions, 1);
    expect(first.fsrsVersion, Fsrs.version);
    expect(first.dueAt.toUtc(), start.add(const Duration(days: 1)));
    expect(first.stability, 8.2956);
    await rate(
      "retry",
      card,
      RecallRating.easy,
      start.add(const Duration(hours: 2)),
      kind: RecallKind.retry,
    );
    expect(await schedule(), first);
    final evidence = {
      for (final row in await store.recentEvidence("en").first) row.id: row,
    };
    expect(evidence["same"]!.recallKind, "scheduled");
    expect(evidence["same"]!.groupPrompt, isTrue);
    expect(evidence["stale"]!.recallKind, "practice");
    expect(evidence["retry"]!.recallKind, "retry");
    expect(evidence["practice"]!.recallKind, "practice");

    await expectLater(
      saveVocabularyReviewSettings(db, (
        enabled: true,
        retentionPercent: 98,
        maximumInterval: 1,
      )),
      throwsArgumentError,
    );
    expect(await loadVocabularyReviewSettings(db), trial);
    await saveVocabularyReviewSettings(db, (
      enabled: true,
      retentionPercent: 90,
      maximumInterval: 180,
    ));
    expect(await schedule(), first);
    final due = first.dueAt.toUtc();
    final selected = (await store.recallCards(
      language: "en",
      dueOnly: true,
      now: due,
      limit: 1,
    )).single;
    await rate("global", selected, RecallRating.good, due, selectedAt: due);
    final second = await schedule();
    expect(second.repetitions, 2);
    expect(second.intervalDays, greaterThan(1));
    expect(second.dueAt.toUtc(), due.add(Duration(days: second.intervalDays)));
  });

  test(
    "failed schedule writes roll back their rating and a retry commits once",
    () async {
      await save("A", ["word"]);
      final card = (await store.cards(language: "en")).single;
      await saveVocabularyReviewSettings(db, (
        enabled: true,
        retentionPercent: 90,
        maximumInterval: 180,
      ));
      final before = await db.select(db.learningReviewSchedules).getSingle();
      await db.customStatement("""
      CREATE TRIGGER reject_review BEFORE UPDATE ON learning_review_schedules
      BEGIN SELECT RAISE(ABORT, 'test failure'); END
    """);
      final localOffset = DateTime.parse("2026-03-07T12:00:00-05:00");
      await expectLater(
        rate("recover", card, RecallRating.good, localOffset),
        throwsException,
      );
      expect(await db.select(db.learningEvidence).get(), isEmpty);
      expect(await db.select(db.learningReviewSchedules).getSingle(), before);
      await db.customStatement("DROP TRIGGER reject_review");
      await rate("recover", card, RecallRating.good, localOffset);
      await rate("recover", card, RecallRating.good, localOffset);
      expect(await db.select(db.learningEvidence).get(), hasLength(1));
      final after = await db.select(db.learningReviewSchedules).getSingle();
      expect(after.updatedAt.toUtc(), DateTime.utc(2026, 3, 7, 17));
      expect(after.dueAt.toUtc(), DateTime.utc(2026, 3, 9, 17));
      expect(after.repetitions, 1);
    },
  );
}
