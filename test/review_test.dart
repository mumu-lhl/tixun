import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/practice/question_spec.dart';
import 'package:tixun/features/review/review_algorithm.dart';
import 'package:tixun/features/review/review_store.dart';
import 'package:tixun/features/progress/learning_progress.dart';
import 'package:tixun/features/progress/learning_profile.dart';

void main() {
  test(
    'Deferred UI refreshes do not inherit a closed nested transaction',
    () async {
      final db = AppDatabase.memory();
      final store = PracticeStore(db);
      final review = ReviewStore(db);
      addTearDown(() async {
        store.dispose();
        review.dispose();
        await db.close();
      });
      final refreshes = <Future<int>>[];
      store.addListener(() {
        refreshes.add(
          Future<void>.delayed(const Duration(milliseconds: 10))
              .then((_) async => (await store.list()).length),
        );
      });
      review.addListener(() {
        refreshes.add(
          Future<void>.delayed(const Duration(milliseconds: 10))
              .then((_) => review.dueCount()),
        );
      });
      await db.transaction(() async {
        final id = await store.create(
          const QuestionSpec(
            kind: 'numeric',
            stem: '1+1',
            answers: [
              ['2'],
            ],
          ),
        );
        await review.enroll(id);
      });
      expect(await Future.wait(refreshes), [1, 1]);
    },
  );

  test(
    'Review intervals use actual independent evidence, hints and finite state',
    () {
      final now = DateTime.utc(2030, 1, 1);
      ReviewDecision next(
        ReviewState s, {
        bool correct = true,
        bool hint = false,
        bool checked = true,
      }) => nextReview(
        s,
        correct: correct,
        hintUsed: hint,
        answerChecked: checked,
        now: now,
      );
      final a = next(const ReviewState()), b = next(a.state), c = next(b.state);
      expect(
        [a.state.intervalDays, b.state.intervalDays, c.state.intervalDays],
        [1, 6, 15],
      );
      expect(next(c.state, hint: true).state.repetitions, 3);
      expect(next(c.state, hint: true).independent, false);
      expect(next(c.state, checked: false).state.repetitions, 3);
      expect(
        next(c.state, checked: false).dueAt,
        now.add(const Duration(days: 1)),
      );
      final fail = next(c.state, correct: false);
      expect(fail.state.repetitions, 0);
      expect(fail.state.lapses, 1);
      expect(fail.dueAt, now.add(const Duration(minutes: 10)));
      expect(
        () => next(const ReviewState(ease: double.nan)),
        throwsFormatException,
      );
    },
  );
  test('Grade and review commit atomically, duplicate evidence and early repeats cannot inflate intervals', () async {
    final db = AppDatabase.memory();
    final review = ReviewStore(db),
        practice = PracticeStore(db)..onGraded = review.record;
    addTearDown(() async {
      practice.dispose();
      review.dispose();
      await db.close();
    });
    final q = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '2+2',
        answers: [
          ['4'],
        ],
        topics: ['加法'],
      ),
    );
    expect(
      await review.dueCount(),
      0,
      reason: 'Reading alone does not enroll or master a topic',
    );
    final start = DateTime.utc(2030, 1, 1);
    final first = await practice.begin(q);
    await practice.submit(first.id, ['4'], now: start);
    final s = (await review.forQuestion(q))!;
    expect(s.repetitions, 1);
    expect(s.dueAt.toUtc(), start.add(const Duration(days: 1)));
    await review.record((await practice.detail(q)).latest!, now: start);
    expect((await review.history(s.id)).length, 1);
    final early = await practice.begin(q, retry: true);
    await practice.submit(early.id, [
      '4',
    ], now: start.add(const Duration(minutes: 1)));
    expect((await review.forQuestion(q))!.repetitions, 1);
    expect((await review.forQuestion(q))!.dueAt, s.dueAt);
    final due = await practice.begin(q, retry: true);
    await practice.submit(due.id, [
      '4',
    ], now: start.add(const Duration(days: 1)));
    expect((await review.forQuestion(q))!.repetitions, 2);
    expect((await review.forQuestion(q))!.intervalDays, 6);
    expect(await review.dueCount(now: start), 0);
    expect(await review.dueCount(now: start.add(const Duration(days: 7))), 1);
    await review.pause(s.id, true);
    final paused = await practice.begin(q, retry: true);
    await practice.submit(paused.id, [
      '0',
    ], now: start.add(const Duration(days: 8)));
    expect((await review.history(s.id)).length, 3);
    expect(await review.dueCount(now: start.add(const Duration(days: 8))), 0);
    await review.adjust(s.id, reset: true);
    expect((await review.forQuestion(q))!.repetitions, 0);
    expect((await review.history(s.id)).any((r) => r.event == 'reset'), true);
    final next = await practice.begin(q, retry: true);
    await db.customStatement(
      "CREATE TRIGGER reject_review BEFORE INSERT ON review_records BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(practice.submit(next.id, ['4']), throwsA(anything));
    expect(
      (await practice.detail(q)).latest!.status,
      'draft',
      reason: 'Review write failure rolls grading back',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('Diagnosis uses distinct latest independently checked questions; self and AI reference are separate', () async {
    final db = AppDatabase.memory();
    final store = PracticeStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      final id = await store.create(
        QuestionSpec(
          kind: 'numeric',
          stem: '$i+1',
          answers: [
            ['${i + 1}'],
          ],
          topics: ['加法'],
        ),
      );
      ids.add(id);
      final a = await store.begin(id);
      await store.submit(a.id, ['${i + 1}']);
    }
    var p = await LearningProgress.load(db);
    expect(p.topics.single.questions, 3);
    expect(p.topics.single.correct, 3);
    final repeated = await store.begin(ids.first, retry: true);
    await store.submit(repeated.id, ['1']);
    p = await LearningProgress.load(db);
    expect(
      p.topics.single.questions,
      3,
      reason: 'Same question repeated is still one sample',
    );
    final hinted = await store.begin(ids.first, retry: true);
    await store.useHint(hinted.id);
    await store.submit(hinted.id, ['1']);
    final ai = await store.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: 'AI 参考',
        answers: [
          ['1'],
        ],
        topics: ['加法'],
      ),
      origin: 'ai',
      verification: 'unverified',
    );
    await store.submit((await store.begin(ai)).id, ['1']);
    final self = await store.create(
      const QuestionSpec(kind: 'short_answer', stem: '解释', answers: []),
      origin: 'recall',
      verification: 'unverified',
    );
    final a = await store.submit((await store.begin(self)).id, ['我的解释']);
    await store.selfGrade(a.id, true);
    p = await LearningProgress.load(db);
    expect(p.topics.single.questions, 2);
    expect(p.topics.single.description, contains('样本不足'));
    expect(p.unverified, 1);
    expect(p.self, 1);
    expect(p.hinted, 1);
    const profile = LearningProfile(
      stage: '职业教育',
      exam: '资格考试',
      dailyMinutes: 60,
      scope: '电路、机械',
      teaching: 'direct',
    );
    await profile.save(db);
    expect((await LearningProfile.load(db)).scope, '电路、机械');
    expect((await LearningProfile.load(db)).teaching, 'direct');
    await expectLater(
      const LearningProfile(dailyMinutes: 0).save(db),
      throwsFormatException,
    );
  });
}
