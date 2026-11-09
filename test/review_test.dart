import 'dart:convert';

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
  test('Grade commits when review scheduling fails; duplicate evidence and early repeats cannot inflate intervals', () async {
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
    // adjust() no longer resumes a paused schedule: resume explicitly so
    // the next grading actually reaches the review write below.
    await review.pause(s.id, false);
    final next = await practice.begin(q, retry: true);
    await db.customStatement(
      "CREATE TRIGGER reject_review BEFORE INSERT ON review_records BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(
      practice.submit(next.id, ['4']),
      throwsA(isA<FormatException>()),
    );
    expect(
      (await practice.detail(q)).latest!.status,
      'graded',
      reason: 'Review scheduling failure keeps the grade',
    );
    expect(await review.history(s.id), hasLength(4));
    expect((await review.forQuestion(q))!.repetitions, 0);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('Adjusting a paused review date does not resume it', () async {
    final db = AppDatabase.memory();
    final review = ReviewStore(db);
    addTearDown(() async {
      review.dispose();
      await db.close();
    });
    final practice = PracticeStore(db)..onGraded = review.record;
    addTearDown(() async {
      practice.dispose();
    });
    final q = await practice.create(
      const QuestionSpec(
        kind: 'numeric',
        stem: '2+2',
        answers: [
          ['4'],
        ],
      ),
    );
    await review.enroll(q);
    final s = (await review.forQuestion(q))!;
    await review.pause(s.id, true);
    expect((await review.forQuestion(q))!.enabled, false);
    final due = DateTime.now().add(const Duration(days: 30));
    await review.adjust(s.id, dueAt: due);
    final after = (await review.forQuestion(q))!;
    expect(after.enabled, false);
    expect(
      (after.dueAt.year, after.dueAt.month, after.dueAt.day),
      (due.year, due.month, due.day),
    );
  });
  test('Corrupt review state cannot roll grading back; scheduling failure is reported', () async {
    final db = AppDatabase.memory();
    final review = ReviewStore(db);
    final practice = PracticeStore(db)..onGraded = review.record;
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
      ),
    );
    await review.enroll(q);
    await db.customStatement(
      "UPDATE review_schedules SET ease=1.0 WHERE question_id='$q'",
    );
    final a = await practice.begin(q);
    await expectLater(
      practice.submit(a.id, ['4']),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          '复习安排失败，可稍后重试。',
        ),
      ),
    );
    expect((await practice.detail(q)).latest!.status, 'graded');
    expect((await review.forQuestion(q))!.ease, 1.0);
    final self = await practice.create(
      const QuestionSpec(kind: 'short_answer', stem: '解释', answers: []),
    );
    await review.enroll(self);
    await db.customStatement(
      "UPDATE review_schedules SET repetitions=-1 WHERE question_id='$self'",
    );
    final sa = await practice.begin(self);
    await practice.submit(sa.id, ['我的解释']);
    await expectLater(
      practice.selfGrade(sa.id, true),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          '复习安排失败，可稍后重试。',
        ),
      ),
    );
    expect((await practice.detail(self)).latest!.status, 'graded');
  });
  test('Learning profile load falls back per field instead of dropping the whole profile', () async {
    final db = AppDatabase.memory();
    addTearDown(() async => db.close());
    await db.setPreference(
      'learning_profile',
      jsonEncode({
        'stage': 42,
        'exam': '中考',
        'exam_date': 'not-a-date',
        'daily_minutes': 45.0,
        'scope': '数学',
        'teaching': 'direct',
      }),
    );
    final loaded = await LearningProfile.load(db);
    expect(loaded.stage, '高中');
    expect(loaded.exam, '中考');
    expect(loaded.examDate, isNull);
    expect(loaded.dailyMinutes, 45);
    expect(loaded.scope, '数学');
    expect(loaded.teaching, 'direct');
    expect(loaded.partialFallback, true);
    await const LearningProfile(
      stage: '初中',
      exam: '中考',
      dailyMinutes: 60,
      scope: '数学',
      teaching: 'direct',
    ).save(db);
    expect((await LearningProfile.load(db)).partialFallback, false);
    await db.setPreference('learning_profile', '{broken');
    final broken = await LearningProfile.load(db);
    expect(broken.stage, '高中');
    expect(broken.dailyMinutes, 45);
    expect(broken.partialFallback, true);
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
