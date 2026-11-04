import 'package:drift/drift.dart';

import '../../core/database/database_notifier.dart';

import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'question_spec.dart';

class QuestionDetail {
  const QuestionDetail(
    this.row,
    this.spec,
    this.attempts,
    this.responses,
    this.images,
  );
  final PracticeQuestion row;
  final QuestionSpec spec;
  final List<PracticeAttempt> attempts;
  final Map<String, List<String>> responses;
  final List<PracticeImage> images;
  PracticeAttempt? get latest => attempts.firstOrNull;
}

class PracticeStore extends DatabaseNotifier {
  PracticeStore(this.db);
  final AppDatabase db;
  Future<void> Function(PracticeAttempt attempt)? onGraded;

  Future<List<PracticeQuestion>> list({
    String query = '',
    String subject = '',
    String? messageId,
  }) =>
      (db.select(db.practiceQuestions)
            ..where(
              (q) =>
                  q.deleted.equals(false) &
                  (query.isEmpty
                      ? const Constant(true)
                      : q.stem.contains(query)) &
                  (subject.isEmpty
                      ? const Constant(true)
                      : q.subject.equals(subject)) &
                  (messageId == null
                      ? const Constant(true)
                      : q.sourceMessageId.equals(messageId)),
            )
            ..orderBy([(q) => OrderingTerm.desc(q.createdAt)])
            ..limit(200))
          .get();

  Future<String> create(
    QuestionSpec spec, {
    String origin = 'manual',
    String verification = 'user_checked',
    String? sessionId,
    String? messageId,
    String? operation,
    String? mistakeId,
    List<String> knowledgeIds = const [],
    String? parentId,
  }) async {
    spec.validate();
    if (!['manual', 'ai', 'template', 'mistake', 'recall'].contains(origin) ||
        ![
          'unverified',
          'user_checked',
          'template_checked',
        ].contains(verification) ||
        (origin == 'ai' && verification != 'unverified')) {
      throw const FormatException('题目来源无效。');
    }
    final id = await db.transaction(() async {
      if (operation != null) {
        final old = await (db.select(
          db.practiceQuestions,
        )..where((q) => q.sourceOperation.equals(operation))).getSingleOrNull();
        if (old != null) return old.id;
      }
      final id = const Uuid().v4();
      await db
          .into(db.practiceQuestions)
          .insert(
            PracticeQuestionsCompanion.insert(
              id: id,
              kind: spec.kind,
              stem: spec.stem,
              subject: spec.subject,
              origin: origin,
              explanation: Value(spec.explanation),
              hint: Value(spec.hint),
              verification: Value(verification),
              absoluteTolerance: Value(spec.absoluteTolerance),
              relativeTolerance: Value(spec.relativeTolerance),
              caseSensitive: Value(spec.caseSensitive),
              timeLimitSeconds: Value(spec.timeLimitSeconds),
              sourceSessionId: Value(sessionId),
              sourceMessageId: Value(messageId),
              sourceOperation: Value(operation),
              mistakeId: Value(mistakeId),
              parentQuestionId: Value(parentId),
              createdAt: DateTime.now(),
            ),
          );
      var position = 0;
      for (final e in spec.options.entries) {
        await db
            .into(db.practiceOptions)
            .insert(
              PracticeOptionsCompanion.insert(
                questionId: id,
                optionId: e.key,
                content: e.value,
                position: position++,
              ),
            );
      }
      for (var i = 0; i < spec.answers.length; i++) {
        for (final a in spec.answers[i]) {
          await db
              .into(db.practiceAnswerKeys)
              .insert(
                PracticeAnswerKeysCompanion.insert(
                  questionId: id,
                  position: i,
                  answer: a,
                ),
              );
        }
      }
      for (final name in spec.topics) {
        var topic =
            await (db.select(db.learningTopics)..where(
                  (t) => t.name.equals(name) & t.subject.equals(spec.subject),
                ))
                .getSingleOrNull();
        if (topic == null) {
          final tid = const Uuid().v4();
          await db
              .into(db.learningTopics)
              .insert(
                LearningTopicsCompanion.insert(
                  id: tid,
                  name: name,
                  subject: spec.subject,
                ),
              );
          topic = await (db.select(
            db.learningTopics,
          )..where((t) => t.id.equals(tid))).getSingle();
        }
        await db
            .into(db.practiceQuestionTopics)
            .insert(
              PracticeQuestionTopicsCompanion.insert(
                questionId: id,
                topicId: topic.id,
              ),
            );
      }
      for (final kid in knowledgeIds.toSet()) {
        await db
            .into(db.practiceQuestionKnowledge)
            .insert(
              PracticeQuestionKnowledgeCompanion.insert(
                questionId: id,
                knowledgeId: kid,
              ),
            );
      }
      if (mistakeId != null) {
        final images = await (db.select(
          db.studyAttachments,
        )..where((a) => a.mistakeId.equals(mistakeId))).get();
        for (final a in images) {
          await db
              .into(db.practiceImages)
              .insert(
                PracticeImagesCompanion.insert(
                  id: const Uuid().v4(),
                  questionId: id,
                  relativePath: a.relativePath,
                  mime: a.mime,
                  byteLength: a.byteLength,
                ),
              );
        }
      }
      return id;
    });
    changed();
    return id;
  }

  Future<QuestionDetail> detail(String id) async {
    final q = await (db.select(
      db.practiceQuestions,
    )..where((q) => q.id.equals(id) & q.deleted.equals(false))).getSingle();
    final options =
        await (db.select(db.practiceOptions)
              ..where((o) => o.questionId.equals(id))
              ..orderBy([(o) => OrderingTerm.asc(o.position)]))
            .get();
    final keys =
        await (db.select(db.practiceAnswerKeys)
              ..where((a) => a.questionId.equals(id))
              ..orderBy([(a) => OrderingTerm.asc(a.position)]))
            .get();
    final answers = <List<String>>[];
    for (final k in keys) {
      while (answers.length <= k.position) {
        answers.add([]);
      }
      answers[k.position].add(k.answer);
    }
    final topics = await db
        .customSelect(
          'SELECT t.name FROM learning_topics t JOIN practice_question_topics l ON t.id=l.topic_id WHERE l.question_id=?',
          variables: [Variable(id)],
        )
        .get();
    final spec = QuestionSpec(
      kind: q.kind,
      stem: q.stem,
      subject: q.subject,
      options: {for (final o in options) o.optionId: o.content},
      answers: answers,
      explanation: q.explanation,
      hint: q.hint,
      topics: topics.map((t) => t.read<String>('name')).toList(),
      absoluteTolerance: q.absoluteTolerance,
      relativeTolerance: q.relativeTolerance,
      caseSensitive: q.caseSensitive,
      timeLimitSeconds: q.timeLimitSeconds,
    );
    spec.validate();
    final attempts =
        await (db.select(db.practiceAttempts)
              ..where((a) => a.questionId.equals(id))
              ..orderBy([
                (a) => OrderingTerm.desc(a.startedAt),
                (a) => OrderingTerm.desc(a.rowId),
              ]))
            .get();
    final responses = <String, List<String>>{};
    for (final a in attempts) {
      final rows =
          await (db.select(db.practiceResponses)
                ..where((r) => r.attemptId.equals(a.id))
                ..orderBy([(r) => OrderingTerm.asc(r.position)]))
              .get();
      responses[a.id] = rows.map((r) => r.answer).toList();
    }
    return QuestionDetail(
      q,
      spec,
      attempts,
      responses,
      await (db.select(
        db.practiceImages,
      )..where((a) => a.questionId.equals(id))).get(),
    );
  }

  Future<PracticeAttempt> begin(String id, {bool retry = false}) async {
    final attempt = await db.transaction(() async {
      final detail = await this.detail(id);
      if (detail.latest != null &&
          (!retry || detail.latest!.status != 'graded')) {
        return detail.latest!;
      }
      final aid = const Uuid().v4();
      await db
          .into(db.practiceAttempts)
          .insert(
            PracticeAttemptsCompanion.insert(
              id: aid,
              questionId: id,
              startedAt: DateTime.now(),
            ),
          );
      return (db.select(
        db.practiceAttempts,
      )..where((a) => a.id.equals(aid))).getSingle();
    });
    changed();
    return attempt;
  }

  Future<PracticeAttempt> _attempt(String id) => (db.select(
    db.practiceAttempts,
  )..where((a) => a.id.equals(id))).getSingle();
  Future<void> draft(String id, List<String> answers) async {
    await db.transaction(() async {
      final a = await _attempt(id);
      if (a.status != 'draft') return;
      _checkResponses(answers);
      await (db.delete(
        db.practiceResponses,
      )..where((r) => r.attemptId.equals(id))).go();
      for (var i = 0; i < answers.length; i++) {
        await db
            .into(db.practiceResponses)
            .insert(
              PracticeResponsesCompanion.insert(
                attemptId: id,
                position: i,
                answer: answers[i],
              ),
            );
      }
    });
  }

  void _checkResponses(List<String> a) {
    if (a.length > 12 || a.any((v) => v.length > 12000)) {
      throw const FormatException('作答内容过长。');
    }
  }

  Future<void> useHint(String id) async {
    await (db.update(db.practiceAttempts)
          ..where((a) => a.id.equals(id) & a.status.equals('draft')))
        .write(const PracticeAttemptsCompanion(hintUsed: Value(true)));
    final a = await _attempt(id);
    if (a.status == 'draft') {
      await _stage((await detail(a.questionId)).row.sourceSessionId, 'hinting');
    }
    changed();
  }

  Future<PracticeAttempt> submit(
    String id,
    List<String> answers, {
    DateTime? now,
  }) async {
    final result = await db.transaction(() async {
      final a = await _attempt(id);
      if (a.status != 'draft') return a;
      _checkResponses(answers);
      final d = await detail(a.questionId);
      if (answers.isEmpty || answers.any((v) => v.trim().isEmpty)) {
        throw const FormatException('请先完成作答。');
      }
      if (d.spec.kind == 'fill_blank' &&
          answers.length != d.spec.answers.length) {
        throw const FormatException('请填写所有空。');
      }
      if ([
            'single_choice',
            'multiple_choice',
            'true_false',
          ].contains(d.spec.kind) &&
          answers.any((v) => !d.spec.options.containsKey(v))) {
        throw const FormatException('选项无效。');
      }
      if (d.spec.kind == 'numeric' &&
          (answers.length != 1 || parseNumber(answers.single) == null)) {
        throw const FormatException('请输入有限数值，支持小数或分数。');
      }
      await draft(id, answers);
      final self = d.spec.kind == 'short_answer';
      final correct = self ? null : d.spec.grade(answers);
      final time = now ?? DateTime.now();
      await (db.update(
        db.practiceAttempts,
      )..where((t) => t.id.equals(id))).write(
        PracticeAttemptsCompanion(
          status: Value(self ? 'awaiting_self_grade' : 'graded'),
          correct: Value(correct),
          score: Value(
            correct == null
                ? null
                : correct
                ? 1
                : 0,
          ),
          gradingBasis: Value(
            self
                ? 'self'
                : d.row.verification == 'unverified'
                ? 'ai_reference'
                : 'deterministic',
          ),
          submittedAt: Value(time),
          elapsedMilliseconds: Value(
            time.difference(a.startedAt).inMilliseconds.clamp(0, 86400000),
          ),
        ),
      );
      final saved = await _attempt(id);
      if (!self) await onGraded?.call(saved);
      await _stage(d.row.sourceSessionId, self ? 'practice' : 'feedback');
      return saved;
    });
    changed();
    return result;
  }

  Future<PracticeAttempt> selfGrade(String id, bool correct) async {
    final result = await db.transaction(() async {
      final a = await _attempt(id);
      if (a.status != 'awaiting_self_grade') return a;
      await (db.update(
        db.practiceAttempts,
      )..where((t) => t.id.equals(id))).write(
        PracticeAttemptsCompanion(
          status: const Value('graded'),
          correct: Value(correct),
          score: Value(correct ? 1 : 0),
        ),
      );
      final saved = await _attempt(id);
      await onGraded?.call(saved);
      await _stage(
        (await detail(a.questionId)).row.sourceSessionId,
        'feedback',
      );
      return saved;
    });
    changed();
    return result;
  }

  Future<void> _stage(String? session, String stage) async {
    if (session != null) {
      await (db.update(db.chatSessions)..where((s) => s.id.equals(session)))
          .write(ChatSessionsCompanion(stage: Value(stage)));
    }
  }

  Future<void> verify(String id) async {
    await (db.update(
      db.practiceQuestions,
    )..where((q) => q.id.equals(id))).write(
      const PracticeQuestionsCompanion(verification: Value('user_checked')),
    );
    changed();
  }

  Future<void> setDeleted(String id, bool value) async {
    await (db.update(db.practiceQuestions)..where((q) => q.id.equals(id)))
        .write(PracticeQuestionsCompanion(deleted: Value(value)));
    changed();
  }
}
