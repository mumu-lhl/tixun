import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'exam_material.dart';
import 'exam_store.dart';
import 'language_store.dart';
import 'written_exam_profile.dart';
import 'writing_task_ai.dart';
import 'writing_store.dart';

class WrittenExamSection {
  const WrittenExamSection(this.row, {this.material, this.writing});
  final LearningWrittenExamSection row;
  final ExamMaterial? material;
  final LearningWritingTaskRow? writing;

  List<String> get answers => (jsonDecode(row.answers) as List).cast<String>();
  int get maximumHalfPoints => answers.length * row.halfPoints;
  int? get earnedHalfPoints {
    final paper = material?.paper;
    if (paper == null) return null;
    final responses = answers;
    return paper.items.indexed
            .where((item) => item.$2.matches(responses[item.$1]))
            .length *
        row.halfPoints;
  }
}

class WrittenExam {
  const WrittenExam(this.row, this.sections);
  final LearningWrittenExam row;
  final List<WrittenExamSection> sections;

  bool get submitted => row.submittedAt != null;
  int get objectiveHalfPoints => sections.fold(
    0,
    (sum, section) =>
        sum + (section.material == null ? 0 : section.maximumHalfPoints),
  );
  int get earnedHalfPoints =>
      sections.fold(0, (sum, section) => sum + (section.earnedHalfPoints ?? 0));

  Duration remaining(DateTime now) {
    final duration = row.deadline.difference(now);
    return duration.isNegative ? Duration.zero : duration;
  }
}

extension WrittenExamStore on LanguageLearningStore {
  Future<List<LearningWrittenExam>> writtenExamHistory() =>
      (db.select(db.learningWrittenExams)
            ..orderBy([
              (row) => OrderingTerm.desc(row.startedAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(15))
          .get();

  Future<WrittenExam> writtenExam(String id) async {
    final run = await (db.select(
      db.learningWrittenExams,
    )..where((row) => row.id.equals(id))).getSingle();
    final sections = db.learningWrittenExamSections;
    final examinations = db.learningExamMaterials;
    final writing = db.learningWritingTasks;
    final rows =
        await (db.select(sections).join([
                leftOuterJoin(
                  examinations,
                  examinations.id.equalsExp(sections.materialId),
                ),
                leftOuterJoin(
                  writing,
                  writing.id.equalsExp(sections.writingTaskId),
                ),
              ])
              ..where(sections.examId.equals(id))
              ..orderBy([OrderingTerm.asc(sections.position)]))
            .get();
    return WrittenExam(run, [
      for (final row in rows)
        WrittenExamSection(
          row.readTable(sections),
          material: switch (row.readTableOrNull(examinations)) {
            final material? => ExamMaterial(material),
            null => null,
          },
          writing: row.readTableOrNull(writing),
        ),
    ]);
  }

  Future<WrittenExam> startWrittenExam({
    required WrittenExamProfile profile,
    required List<ExamMaterial> objectives,
    required List<LearningWritingTaskRow> essays,
    DateTime? now,
  }) => runOperation(
    () => db.transaction(() async {
      final active =
          await (db.select(db.learningWrittenExams)
                ..where((row) => row.submittedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (active != null) return writtenExam(active.id);
      final objectiveSpecs = profile.sections
          .where((row) => row.kind != null)
          .toList();
      final essaySpecs = profile.sections
          .where((row) => row.writing != null)
          .toList();
      if (profile.sections.isEmpty ||
          profile.duration <= Duration.zero ||
          objectives.length != objectiveSpecs.length ||
          essays.length != essaySpecs.length ||
          objectives.map((paper) => paper.row.id).toSet().length !=
              objectives.length ||
          essays.map((task) => task.id).toSet().length != essays.length) {
        throw const FormatException('Invalid written exam sections');
      }
      final id = const Uuid().v4();
      final start = now ?? DateTime.now();
      await db
          .into(db.learningWrittenExams)
          .insert(
            LearningWrittenExamsCompanion.insert(
              id: id,
              profile: profile.id,
              startedAt: start,
              deadline: start.add(profile.duration),
              sectionStartedAt: start,
            ),
          );
      var objective = 0;
      var essay = 0;
      for (final (position, spec) in profile.sections.indexed) {
        final paper = spec.kind == null ? null : objectives[objective++];
        final task = spec.writing == null ? null : essays[essay++];
        if (paper != null &&
                (paper.target.kind != spec.kind ||
                    paper.target.profile != profile.exam ||
                    paper.paper.items.length != spec.count ||
                    paper.source == ExamSource.bundled ||
                    paper.row.model == 'Mock' ||
                    paper.verification == ExamVerification.reviewRejected) ||
            task != null &&
                (task.kind != spec.writing!.name ||
                    task.profile != profile.exam.id ||
                    task.model == 'Mock')) {
          throw const FormatException(
            'Written exam material does not match the profile',
          );
        }
        await db
            .into(db.learningWrittenExamSections)
            .insert(
              LearningWrittenExamSectionsCompanion.insert(
                examId: id,
                position: position,
                materialId: Value(paper?.row.id),
                writingTaskId: Value(task?.id),
                answers: jsonEncode(List.filled(spec.count, '')),
                halfPoints: spec.halfPoints,
                reviewedAtStart: Value(
                  paper?.verification == ExamVerification.aiReviewed,
                ),
              ),
            );
      }
      return writtenExam(id);
    }),
  );

  Future<void> editWrittenSection({
    required String id,
    required int position,
    required List<String> answers,
    DateTime? now,
  }) => runOperation(
    () => db.transaction(() async {
      final run = await writtenExam(id);
      final time = now ?? DateTime.now();
      if (run.submitted || !time.isBefore(run.row.deadline)) return;
      if (position < 0 || position >= run.sections.length) {
        throw const FormatException('Invalid written exam section');
      }
      final entry = run.sections[position];
      final paper = entry.material;
      if (answers.length != entry.answers.length ||
          answers.indexed.any((value) {
            if (paper == null) return value.$2.length > 12000;
            final choices = paper.paper.optionsFor(value.$1);
            return value.$2.length > 100 ||
                (value.$2.isNotEmpty &&
                    choices.isNotEmpty &&
                    !choices.containsKey(value.$2));
          })) {
        throw const FormatException('Invalid written exam answer');
      }
      if (paper?.target.kind == ExamKind.sentenceInsertion) {
        final assigned = answers
            .where((response) => response.isNotEmpty)
            .toList();
        if (assigned.toSet().length != assigned.length) {
          throw const FormatException('Duplicate insertion option');
        }
      }
      await (db.update(db.learningWrittenExamSections)..where(
            (row) => row.examId.equals(id) & row.position.equals(position),
          ))
          .write(
            LearningWrittenExamSectionsCompanion(
              answers: Value(jsonEncode(answers)),
            ),
          );
    }),
  );

  Future<WrittenExam> selectWrittenSection(
    String id,
    int position, {
    DateTime? now,
  }) => runOperation(
    () => db.transaction(() async {
      final run = await writtenExam(id);
      final time = now ?? DateTime.now();
      if (position < 0 ||
          position >= run.sections.length ||
          run.submitted ||
          !time.isBefore(run.row.deadline) ||
          position == run.row.currentSection) {
        return run;
      }
      await _addSectionTime(run, time);
      await (db.update(
        db.learningWrittenExams,
      )..where((row) => row.id.equals(id))).write(
        LearningWrittenExamsCompanion(
          currentSection: Value(position),
          sectionStartedAt: Value(time),
        ),
      );
      return writtenExam(id);
    }),
  );

  Future<WrittenExam> submitWrittenExam(String id, {DateTime? now}) =>
      runOperation(
        () => db.transaction(() async {
          final run = await writtenExam(id);
          if (run.submitted) return run;
          final time = now ?? DateTime.now();
          final finish = time.isAfter(run.row.deadline)
              ? run.row.deadline
              : time;
          await _addSectionTime(run, finish);
          for (final section in run.sections) {
            if (section.material case final material?) {
              await submitExam(
                material: material,
                attemptId: ['written', id, section.row.position].join(':'),
                responses: section.answers,
                confidence: null,
                hintUsed: false,
                allowBlank: true,
                reviewedAtStart: section.row.reviewedAtStart,
              );
            }
          }
          await (db.update(db.learningWrittenExams)
                ..where((row) => row.id.equals(id)))
              .write(LearningWrittenExamsCompanion(submittedAt: Value(finish)));
          return writtenExam(id);
        }),
      );

  Future<void> attachWrittenFeedback(String id, int position, String version) =>
      runOperation(() async {
        final run = await writtenExam(id);
        if (!run.submitted || run.sections[position].writing == null) return;
        await (db.update(db.learningWrittenExamSections)..where(
              (row) => row.examId.equals(id) & row.position.equals(position),
            ))
            .write(
              LearningWrittenExamSectionsCompanion(
                writingVersionId: Value(version),
              ),
            );
      });

  Future<void> _addSectionTime(WrittenExam run, DateTime time) async {
    final current = run.sections[run.row.currentSection].row;
    final spent = time.difference(run.row.sectionStartedAt).inSeconds;
    await (db.update(db.learningWrittenExamSections)..where(
          (row) =>
              row.examId.equals(run.row.id) &
              row.position.equals(current.position),
        ))
        .write(
          LearningWrittenExamSectionsCompanion(
            seconds: Value(current.seconds + (spent < 0 ? 0 : spent)),
          ),
        );
  }

  Future<LearningWritingTaskRow?> reusableMockEssay(
    ExamProfile exam,
    WritingTaskKind kind,
  ) async {
    final task = db.learningWritingTasks;
    final version = db.learningWritingVersions;
    final section = db.learningWrittenExamSections;
    final exercised = db.selectOnly(version)
      ..addColumns([version.id])
      ..where(version.taskId.equalsExp(task.id));
    final assigned = db.selectOnly(section)
      ..addColumns([section.examId])
      ..where(section.writingTaskId.equalsExp(task.id));
    return (db.select(task)
          ..where(
            (row) =>
                row.profile.equals(exam.id) &
                row.kind.equals(kind.name) &
                row.model.equals('Mock').not() &
                notExistsQuery(exercised) &
                notExistsQuery(assigned),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<LearningWritingTaskRow> mockEssayRow(String id) => (db.select(
    db.learningWritingTasks,
  )..where((row) => row.id.equals(id))).getSingle();
}

WritingTask isolatedWrittenTask(WrittenExam run, LearningWritingTaskRow row) {
  final task = openWritingTask(row);
  return WritingTask(
    ['written', run.row.id, task.id].join(':'),
    task.prompt,
    title: task.title,
    passage: task.passage,
    rubric: task.rubric,
  );
}
