import 'package:tixun/core/l10n/app_error.dart';

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/database_notifier.dart';

import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/attachment_cleanup.dart';
import '../../core/platform/attachment_store.dart';
import '../../core/platform/attachment_selection.dart';
import 'question_spec.dart';
import 'practice_run.dart';

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
  PracticeStore(this.db, {this.files});
  final AttachmentStore? files;
  final AppDatabase db;
  Future<void> Function(PracticeAttempt attempt)? onGraded;

  Future<String> revise(String parentId, QuestionSpec spec) => runOperation(
    () => db.transaction(() async {
      final previous = await detail(parentId);
      final links = await (db.select(
        db.practiceQuestionKnowledge,
      )..where((l) => l.questionId.equals(parentId))).get();
      return create(
        spec,
        parentId: parentId,
        mistakeId: previous.row.mistakeId,
        knowledgeIds: links.map((l) => l.knowledgeId).toList(),
      );
    }),
  );

  Future<List<PracticeQuestion>> list({
    String query = '',
    String subject = '',
    String? messageId,
    bool trash = false,
    int limit = 200,
  }) =>
      (db.select(db.practiceQuestions)
            ..where(
              (q) =>
                  q.deleted.equals(trash) &
                  (query.isEmpty
                      ? const Constant(true)
                      : q.stem.contains(query)) &
                  (subject.isEmpty
                      ? const Constant(true)
                      : q.subject.equals(subject)) &
                  (messageId == null
                      ? const Constant(true)
                      : q.sourceMessageId.equals(messageId) |
                            q.id.isInQuery(
                              db.selectOnly(db.practiceChatLinks)
                                ..addColumns([db.practiceChatLinks.questionId])
                                ..where(
                                  db.practiceChatLinks.messageId.equals(
                                    messageId,
                                  ),
                                ),
                            )),
            )
            ..orderBy([(q) => OrderingTerm.desc(q.createdAt)])
            ..limit(limit))
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
    List<Attachment> sourceImages = const [],
  }) => runOperation(() async {
    spec.validate();
    if (!['manual', 'ai', 'template', 'mistake', 'recall'].contains(origin) ||
        ![
          'unverified',
          'user_checked',
          'template_checked',
        ].contains(verification) ||
        (origin == 'ai' && verification != 'unverified')) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionSource,
        '题目来源无效。',
      );
    }
    final id = await db.transaction(() async {
      if (operation != null) {
        final old = await (db.select(
          db.practiceQuestions,
        )..where((q) => q.sourceOperation.equals(operation))).getSingleOrNull();
        if (old != null) {
          // Same operation replayed: return the old question only when the
          // content matches. Changed content must never be silently dropped.
          String canonical(Object? value) {
            Object? sort(Object? v) {
              if (v is Map) {
                final keys = v.keys.cast<String>().toList()..sort();
                return {for (final k in keys) k: sort(v[k])};
              }
              if (v is List) return v.map(sort).toList();
              return v;
            }

            return jsonEncode(sort(value));
          }

          Map<String, dynamic> normalized(QuestionSpec s) {
            final json = s.toJson();
            json['topics'] = (List<String>.from(json['topics'] as List)
              ..sort());
            return json;
          }

          final oldOptions =
              await (db.select(db.practiceOptions)
                    ..where((o) => o.questionId.equals(old.id))
                    ..orderBy([(o) => OrderingTerm.asc(o.position)]))
                  .get();
          final oldKeys =
              await (db.select(db.practiceAnswerKeys)
                    ..where((a) => a.questionId.equals(old.id))
                    ..orderBy([(a) => OrderingTerm.asc(a.position)]))
                  .get();
          final oldAnswers = <List<String>>[];
          for (final k in oldKeys) {
            while (oldAnswers.length <= k.position) {
              oldAnswers.add([]);
            }
            oldAnswers[k.position].add(k.answer);
          }
          final oldTopics = await db
              .customSelect(
                'SELECT t.name FROM learning_topics t JOIN practice_question_topics l ON t.id=l.topic_id WHERE l.question_id=?',
                variables: [Variable(old.id)],
              )
              .get();
          final oldSpec = QuestionSpec(
            kind: old.kind,
            stem: old.stem,
            subject: old.subject,
            options: {for (final o in oldOptions) o.optionId: o.content},
            answers: oldAnswers,
            explanation: old.explanation,
            hint: old.hint,
            topics: oldTopics.map((t) => t.read<String>('name')).toList(),
            absoluteTolerance: old.absoluteTolerance,
            relativeTolerance: old.relativeTolerance,
            caseSensitive: old.caseSensitive,
            timeLimitSeconds: old.timeLimitSeconds,
          );
          if (canonical(normalized(oldSpec)) != canonical(normalized(spec))) {
            throw const AppFormatException(
              AppErrorCode.errorThisOperationAlreadyCreatedAQuestion,
              '该操作已创建过题目，内容与之前不一致，未覆盖旧题。',
            );
          }
          if (old.deleted) {
            await (db.update(db.practiceQuestions)
                  ..where((q) => q.id.equals(old.id)))
                .write(const PracticeQuestionsCompanion(deleted: Value(false)));
          }
          return old.id;
        }
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
      if (messageId != null) {
        await db
            .into(db.practiceChatLinks)
            .insert(
              PracticeChatLinksCompanion.insert(
                questionId: id,
                messageId: messageId,
              ),
            );
      }
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
      final imageRefs = <({String path, String mime, int bytes})>[];
      if (origin == 'ai') {
        imageRefs.addAll(
          sourceImages.map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      } else if (parentId != null) {
        final images = await (db.select(
          db.practiceImages,
        )..where((a) => a.questionId.equals(parentId))).get();
        imageRefs.addAll(
          images.map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      } else if (mistakeId != null) {
        final images =
            await (db.select(db.studyAttachments)
                  ..where((a) => a.mistakeId.equals(mistakeId))
                  ..orderBy([(a) => OrderingTerm.asc(a.rowId)]))
                .get();
        imageRefs.addAll(
          preferredStudyImages(images).map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      }
      for (final a in imageRefs) {
        await db
            .into(db.practiceImages)
            .insert(
              PracticeImagesCompanion.insert(
                id: const Uuid().v4(),
                questionId: id,
                relativePath: a.path,
                mime: a.mime,
                byteLength: a.bytes,
              ),
            );
      }
      return id;
    });
    changed();
    return id;
  });

  Future<QuestionDetail> detail(String id, {String? attemptId}) async {
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
    final storedAttempts =
        await (db.select(db.practiceAttempts)
              ..where((a) => a.questionId.equals(id))
              ..orderBy([(a) => OrderingTerm.desc(a.rowId)])
              ..limit(50))
            .get();
    final attempts = List<PracticeAttempt>.of(storedAttempts);
    if (attemptId != null) {
      final focused =
          await (db.select(
                db.practiceAttempts,
              )..where((a) => a.id.equals(attemptId) & a.questionId.equals(id)))
              .getSingle();
      attempts.removeWhere((a) => a.id == attemptId);
      attempts.insert(0, focused);
      if (attempts.length > 50) attempts.removeLast();
    }
    final responses = <String, List<String>>{};
    if (attempts.isNotEmpty) {
      final rows =
          await (db.select(db.practiceResponses)
                ..where((r) => r.attemptId.isIn(attempts.map((a) => a.id)))
                ..orderBy([(r) => OrderingTerm.asc(r.position)]))
              .get();
      for (final r in rows) {
        responses.putIfAbsent(r.attemptId, () => []).add(r.answer);
      }
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

  Future<PracticeAttempt> begin(String id, {bool retry = false}) =>
      runOperation(() async {
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
      });

  Future<PracticeAttempt> _attempt(String id) => (db.select(
    db.practiceAttempts,
  )..where((a) => a.id.equals(id))).getSingle();
  Future<void> _draftTail = Future.value();
  Future<void> flushDrafts() => _draftTail;
  Future<void> draft(String id, List<String> answers) {
    final snapshot = List<String>.of(answers);
    final next = _draftTail
        .catchError((Object _) {})
        .then((_) => _writeDraft(id, snapshot));
    _draftTail = next;
    return next;
  }

  Future<void> _writeDraft(String id, List<String> answers) async {
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
      throw const AppFormatException(
        AppErrorCode.errorTheAnswerIsTooLong,
        '作答内容过长。',
      );
    }
  }

  Future<void> useHint(String id) => runOperation(() async {
    await (db.update(db.practiceAttempts)
          ..where((a) => a.id.equals(id) & a.status.equals('draft')))
        .write(const PracticeAttemptsCompanion(hintUsed: Value(true)));
    final a = await _attempt(id);
    if (a.status == 'draft') {
      await _stage(a.questionId, 'hinting');
    }
    changed();
  });

  Future<PracticeAttempt> submit(
    String id,
    List<String> answers, {
    DateTime? now,
  }) => runOperation(() async {
    await flushDrafts();
    var gradedNow = false;
    final result = await db.transaction(() async {
      final a = await _attempt(id);
      if (a.status != 'draft') return a;
      _checkResponses(answers);
      final d = await detail(a.questionId);
      if (answers.isEmpty || answers.any((v) => v.trim().isEmpty)) {
        throw const AppFormatException(
          AppErrorCode.errorCompleteYourAnswerFirst,
          '请先完成作答。',
        );
      }
      if (d.spec.kind == 'fill_blank' &&
          answers.length != d.spec.answers.length) {
        throw const AppFormatException(
          AppErrorCode.errorFillInAllBlanks,
          '请填写所有空。',
        );
      }
      if ([
            'single_choice',
            'multiple_choice',
            'true_false',
          ].contains(d.spec.kind) &&
          answers.any((v) => !d.spec.options.containsKey(v))) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidOption,
          '选项无效。',
        );
      }
      if (d.spec.kind == 'numeric' &&
          (answers.length != 1 || parseNumber(answers.single) == null)) {
        throw const AppFormatException(
          AppErrorCode.errorEnterAFiniteNumberDecimalOr,
          '请输入有限数值，支持小数或分数。',
        );
      }
      await _writeDraft(id, answers);
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
      gradedNow = !self;
      await _stage(d.row.id, self ? 'practice' : 'feedback');
      return saved;
    });
    changed();
    if (gradedNow) await _scheduleReview(result);
    return result;
  });

  Future<PracticeAttempt> selfGrade(String id, bool correct) =>
      runOperation(() async {
        var gradedNow = false;
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
          gradedNow = true;
          await _stage(a.questionId, 'feedback');
          return saved;
        });
        changed();
        if (gradedNow) await _scheduleReview(result);
        return result;
      });

  /// Schedules review only after the grading transaction has committed, so
  /// a corrupt review schedule can never roll grading back. A scheduling
  /// failure is still reported to the caller, but the grade is kept: the
  /// next attempt re-runs scheduling through the duplicate guard.
  Future<void> _scheduleReview(PracticeAttempt attempt) async {
    final schedule = onGraded;
    if (schedule == null) return;
    try {
      await schedule(attempt);
    } catch (_) {
      throw const AppFormatException(
        AppErrorCode.reviewSchedulingFailedButYour,
        '复习安排失败，可稍后重试。',
      );
    }
  }

  Future<void> _stage(String question, String stage) async {
    final sessions = await db
        .customSelect(
          'SELECT DISTINCT m.session_id FROM practice_chat_links l JOIN chat_messages m ON m.id=l.message_id WHERE l.question_id=?',
          variables: [Variable(question)],
        )
        .get();
    for (final row in sessions) {
      await (db.update(db.chatSessions)
            ..where((s) => s.id.equals(row.read<String>('session_id'))))
          .write(ChatSessionsCompanion(stage: Value(stage)));
    }
  }

  Future<void> linkFork(String sourceMessage, String targetMessage) async {
    final questions = await db
        .customSelect(
          'SELECT question_id FROM practice_chat_links WHERE message_id=? UNION SELECT id FROM practice_questions WHERE source_message_id=?',
          variables: [Variable(sourceMessage), Variable(sourceMessage)],
        )
        .get();
    for (final row in questions) {
      await db
          .into(db.practiceChatLinks)
          .insert(
            PracticeChatLinksCompanion.insert(
              questionId: row.read<String>('question_id'),
              messageId: targetMessage,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<List<PracticeAttempt>> history(String id, {int offset = 0}) =>
      (db.select(db.practiceAttempts)
            ..where((a) => a.questionId.equals(id))
            ..orderBy([(a) => OrderingTerm.desc(a.rowId)])
            ..limit(50, offset: offset.clamp(0, 10000000)))
          .get();

  Future<PracticeRun?> loadRun() async {
    final raw = await db.preference('practice_run');
    if (raw == null || raw.isEmpty) return null;
    try {
      final run = PracticeRun.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      final questions = await (db.select(
        db.practiceQuestions,
      )..where((q) => q.id.isIn(run.ids) & q.deleted.equals(false))).get();
      if (questions.length != run.ids.length) {
        throw const AppFormatException(
          AppErrorCode.errorAQuestionInThisQuizWas,
          '小测中的题目已删除，请结束本轮后重新选择。已有记录保留。',
        );
      }
      final known = run.attempts.whereType<String>().toList();
      final attempts = await (db.select(
        db.practiceAttempts,
      )..where((a) => a.id.isIn(known))).get();
      final byId = {for (final a in attempts) a.id: a};
      for (var i = 0; i < run.ids.length; i++) {
        if (i <= run.index) {
          final a = byId[run.attempts[i]];
          if (a == null ||
              a.questionId != run.ids[i] ||
              (i < run.index && a.status != 'graded')) {
            throw const AppFormatException(
              AppErrorCode.errorTheQuizAnswerStateIsInconsistent,
              '小测作答状态不一致，请结束本轮；已有记录保留。',
            );
          }
        } else if (run.attempts[i] != null) {
          throw const AppFormatException(
            AppErrorCode.errorTheQuizProgressIsInconsistentEnd,
            '小测进度不一致，请结束本轮；已有记录保留。',
          );
        }
      }
      return run;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const AppFormatException(
        AppErrorCode.errorTheQuizStateCouldNotBe,
        '小测状态无法恢复，请结束本轮后重新开始；已有作答仍保留。',
      );
    }
  }

  Future<PracticeRun> startRandomRun({
    String subject = '',
  }) => runOperation(() async {
    final rows = await db
        .customSelect(
          'SELECT id FROM practice_questions WHERE deleted=0 ${subject.isEmpty ? '' : 'AND subject=?'} ORDER BY RANDOM() LIMIT 5',
          variables: [if (subject.isNotEmpty) Variable(subject)],
        )
        .get();
    if (rows.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorThereAreNoQuestionsYetEnter,
        '还没有已有题目。请先手动录题、使用离线基础题，或让 AI 生成练习。',
      );
    }
    final ids = rows.map((r) => r.read<String>('id')).toList();
    final run = await db.transaction(() async {
      final previous = await loadRun();
      if (previous != null && !previous.completed) return previous;
      final attempt = await begin(ids.first, retry: true);
      final run = PracticeRun(
        ids,
        List<String?>.filled(ids.length, null)..[0] = attempt.id,
        0,
      );
      await db.setPreference('practice_run', jsonEncode(run.toJson()));
      return run;
    });
    changed();
    return run;
  });
  Future<PracticeRun> advanceRun({String? expectedAttemptId}) => runOperation(
    () async {
      final next = await db.transaction(() async {
        final run = await loadRun();
        if (run == null)
          throw const AppFormatException(
            AppErrorCode.errorThisQuizRoundDoesNotExist,
            '本轮小测不存在。',
          );
        if (run.completed) return run;
        final a = run.attempts[run.index];
        if (expectedAttemptId != null && a != expectedAttemptId) return run;
        if (a == null || (await _attempt(a)).status != 'graded') {
          throw const AppFormatException(
            AppErrorCode.errorSubmitAndGradeTheAnswerFirst,
            '请先提交答案并完成评分。',
          );
        }
        final index = run.index + 1, attempts = List<String?>.of(run.attempts);
        if (index < run.ids.length) {
          attempts[index] = (await begin(run.ids[index], retry: true)).id;
        }
        final next = PracticeRun(run.ids, attempts, index);
        await db.setPreference('practice_run', jsonEncode(next.toJson()));
        return next;
      });
      changed();
      return next;
    },
  );
  Future<void> clearRun() => runOperation(() async {
    await db.setPreference('practice_run', '');
    changed();
  });

  Future<int> purge(String id) => runOperation(() async {
    final paths = <String>[];
    await db.transaction(() async {
      await (db.select(
        db.practiceQuestions,
      )..where((q) => q.id.equals(id) & q.deleted.equals(true))).getSingle();
      paths.addAll(
        (await (db.select(
          db.practiceImages,
        )..where((a) => a.questionId.equals(id))).get()).map(
          (a) => a.relativePath,
        ),
      );
      await (db.delete(
        db.practiceQuestions,
      )..where((q) => q.id.equals(id))).go();
    });
    changed();
    return files == null ? 0 : cleanupPurgedAttachments(db, files!, paths);
  });

  Future<void> verify(String id) => runOperation(() async {
    await (db.update(
      db.practiceQuestions,
    )..where((q) => q.id.equals(id))).write(
      const PracticeQuestionsCompanion(verification: Value('user_checked')),
    );
    changed();
  });

  Future<void> setDeleted(String id, bool value) => runOperation(() async {
    await (db.update(db.practiceQuestions)..where((q) => q.id.equals(id)))
        .write(PracticeQuestionsCompanion(deleted: Value(value)));
    changed();
  });
}
