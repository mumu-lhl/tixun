import 'package:drift/drift.dart';

import '../../core/database/database_notifier.dart';

import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'review_algorithm.dart';

class ReviewItem {
  const ReviewItem(this.schedule, this.question);
  final ReviewSchedule schedule;
  final PracticeQuestion question;
}

class ReviewStore extends DatabaseNotifier {
  ReviewStore(this.db);
  final AppDatabase db;

  Future<ReviewSchedule?> forQuestion(String id) => (db.select(
    db.reviewSchedules,
  )..where((s) => s.questionId.equals(id))).getSingleOrNull();
  Future<ReviewSchedule> _schedule(String id) => (db.select(
    db.reviewSchedules,
  )..where((s) => s.id.equals(id))).getSingle();
  Future<ReviewSchedule> enroll(String questionId, {DateTime? now}) =>
      runOperation(() async {
        final time = now ?? DateTime.now();
        final result = await db.transaction(() async {
          await (db.select(db.practiceQuestions)..where(
                (q) => q.id.equals(questionId) & q.deleted.equals(false),
              ))
              .getSingle();
          final old = await forQuestion(questionId);
          if (old != null) {
            await (db.update(
              db.reviewSchedules,
            )..where((s) => s.id.equals(old.id))).write(
              ReviewSchedulesCompanion(
                enabled: const Value(true),
                updatedAt: Value(time),
              ),
            );
            return _schedule(old.id);
          }
          final id = const Uuid().v4();
          await db
              .into(db.reviewSchedules)
              .insert(
                ReviewSchedulesCompanion.insert(
                  id: id,
                  questionId: questionId,
                  dueAt: time,
                  createdAt: time,
                  updatedAt: time,
                ),
              );
          return _schedule(id);
        });
        changed();
        return result;
      });

  Future<void> record(PracticeAttempt attempt, {DateTime? now}) =>
      runOperation(() async {
        await db.transaction(() async {
          // Accept only committed-in-this-transaction database evidence, never a model-provided score.
          final a = await (db.select(
            db.practiceAttempts,
          )..where((a) => a.id.equals(attempt.id))).getSingle();
          if (a.status != 'graded' || a.correct == null) {
            throw const FormatException('尚未完成评分，不能安排复习。');
          }
          final time = now ?? a.submittedAt ?? DateTime.now();
          final existing = await forQuestion(a.questionId);
          if (existing?.enabled == false) return;
          final schedule = existing ?? await enroll(a.questionId, now: time);
          final duplicate =
              await (db.select(db.reviewRecords)..where(
                    (r) =>
                        r.scheduleId.equals(schedule.id) &
                        r.attemptId.equals(a.id),
                  ))
                  .getSingleOrNull();
          if (duplicate != null) return;
          final previous = ReviewState(
            repetitions: schedule.repetitions,
            intervalDays: schedule.intervalDays,
            ease: schedule.ease,
            lapses: schedule.lapses,
          );
          var decision = nextReview(
            previous,
            correct: a.correct!,
            hintUsed: a.hintUsed,
            answerChecked: a.gradingBasis != 'ai_reference',
            now: time,
          );
          final hasEvidence =
              await (db.select(db.reviewRecords)
                    ..where(
                      (r) =>
                          r.scheduleId.equals(schedule.id) &
                          r.event.equals('graded'),
                    )
                    ..limit(1))
                  .get();
          if (a.correct! &&
              schedule.dueAt.isAfter(time) &&
              hasEvidence.isNotEmpty) {
            decision = ReviewDecision(
              previous,
              schedule.dueAt,
              decision.quality,
              decision.independent,
              '提前练习已记录；保留原复习日期，避免短时间重复作答拉长间隔。',
            );
          }
          await (db.update(
            db.reviewSchedules,
          )..where((s) => s.id.equals(schedule.id))).write(
            ReviewSchedulesCompanion(
              dueAt: Value(decision.dueAt),
              repetitions: Value(decision.state.repetitions),
              intervalDays: Value(decision.state.intervalDays),
              ease: Value(decision.state.ease),
              lapses: Value(decision.state.lapses),
              updatedAt: Value(time),
            ),
          );
          await db
              .into(db.reviewRecords)
              .insert(
                ReviewRecordsCompanion.insert(
                  id: const Uuid().v4(),
                  scheduleId: schedule.id,
                  attemptId: Value(a.id),
                  event: 'graded',
                  previousDueAt: schedule.dueAt,
                  nextDueAt: decision.dueAt,
                  quality: Value(decision.quality),
                  independent: Value(decision.independent),
                  reason: decision.reason,
                  recordedAt: time,
                ),
              );
        });
        changed();
      });

  Future<List<ReviewItem>> list({
    bool dueOnly = false,
    DateTime? now,
    bool paused = false,
    String subject = '',
    int limit = 200,
  }) async {
    final joined = db.select(db.reviewSchedules).join([
      innerJoin(
        db.practiceQuestions,
        db.practiceQuestions.id.equalsExp(db.reviewSchedules.questionId),
      ),
    ]);
    joined.where(
      db.reviewSchedules.enabled.equals(!paused) &
          db.practiceQuestions.deleted.equals(false) &
          (subject.isEmpty
              ? const Constant(true)
              : db.practiceQuestions.subject.equals(subject)),
    );
    if (dueOnly) {
      joined.where(
        db.reviewSchedules.dueAt.isSmallerOrEqualValue(now ?? DateTime.now()),
      );
    }
    joined.orderBy([OrderingTerm.asc(db.reviewSchedules.dueAt)]);
    joined.limit(limit);
    return (await joined.get())
        .map(
          (r) => ReviewItem(
            r.readTable(db.reviewSchedules),
            r.readTable(db.practiceQuestions),
          ),
        )
        .toList();
  }

  Future<int> dueCount({DateTime? now}) async =>
      (await db
              .customSelect(
                'SELECT count(*) n FROM review_schedules s JOIN practice_questions q ON q.id=s.question_id WHERE s.enabled=1 AND q.deleted=0 AND s.due_at<=?',
                variables: [
                  Variable(
                    (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
                  ),
                ],
              )
              .getSingle())
          .read<int>('n');
  Future<List<ReviewRecord>> history(String id) =>
      (db.select(db.reviewRecords)
            ..where((r) => r.scheduleId.equals(id))
            ..orderBy([(r) => OrderingTerm.desc(r.recordedAt)])
            ..limit(100))
          .get();
  Future<void> pause(String id, bool paused) => runOperation(() async {
    await (db.update(db.reviewSchedules)..where((s) => s.id.equals(id))).write(
      ReviewSchedulesCompanion(
        enabled: Value(!paused),
        updatedAt: Value(DateTime.now()),
      ),
    );
    changed();
  });

  Future<void> adjust(String id, {DateTime? dueAt, bool reset = false}) =>
      runOperation(() async {
        final now = DateTime.now(), due = dueAt ?? DateTime.now();
        if (due.isBefore(now.subtract(const Duration(days: 1))) ||
            due.isAfter(now.add(const Duration(days: 366)))) {
          throw const FormatException('日期需在今天至一年内。');
        }
        await db.transaction(() async {
          final s = await _schedule(id);
          await (db.update(
            db.reviewSchedules,
          )..where((s) => s.id.equals(id))).write(
            ReviewSchedulesCompanion(
              dueAt: Value(due),
              repetitions: reset ? const Value(0) : const Value.absent(),
              intervalDays: reset ? const Value(0) : const Value.absent(),
              ease: reset ? const Value(2.5) : const Value.absent(),
              lapses: reset ? const Value(0) : const Value.absent(),
              updatedAt: Value(now),
            ),
          );
          await db
              .into(db.reviewRecords)
              .insert(
                ReviewRecordsCompanion.insert(
                  id: const Uuid().v4(),
                  scheduleId: id,
                  event: reset ? 'reset' : 'reschedule',
                  previousDueAt: s.dueAt,
                  nextDueAt: due,
                  reason: reset ? '用户重置复习进度；历史作答仍保留。' : '用户手动调整复习日期。',
                  recordedAt: now,
                ),
              );
        });
        changed();
      });
}
