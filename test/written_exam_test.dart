import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/language_learning/exam_material.dart';
import 'package:tixun/features/language_learning/exam_store.dart';
import 'package:tixun/features/language_learning/language_profile_store.dart';
import 'package:tixun/features/language_learning/language_skills.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/sentence_content.dart';
import 'package:tixun/features/language_learning/written_exam_profile.dart';
import 'package:tixun/features/language_learning/written_exam_store.dart';
import 'package:tixun/features/language_learning/writing_task_ai.dart';

import 'support/exam_bundled.dart';

void main() {
  test('versioned Zhejiang written plan counts all available sections', () {
    const profile = WrittenExamProfile.zhejiang2026;
    expect(profile.sections, hasLength(9));
    expect(profile.maximumHalfPoints, 240);
    expect(profile.objectiveHalfPoints, 160);
    expect(profile.duration.inMinutes, 100);
    expect(
      profile.sections
          .where((part) => part.kind == ExamKind.reading)
          .fold(0, (sum, section) => sum + section.count),
      15,
    );
  });

  test('timed exam resumes answers and time, grades blanks, and commits exactly once', () async {
    final root = await Directory.systemTemp.createTemp('tixun-written-test');
    final file = File([root.path, 'test.sqlite'].join(Platform.pathSeparator));
    var db = AppDatabase.file(file);
    var store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    const profile = WrittenExamProfile(
      id: 'fixture-written-v1',
      region: 'Zhejiang',
      year: 2026,
      exam: ExamProfile.zhejiang2026,
      duration: Duration(minutes: 2),
      sections: [
        WrittenSectionSpec.objective(ExamKind.grammar, 5, 3),
        WrittenSectionSpec.writing(WritingTaskKind.application, 30),
      ],
    );
    final target = ExamTarget(
      kind: ExamKind.grammar,
      level: SentenceLevel.beginner,
      count: 5,
    );
    final paper = bundledExamPapers(ExamKind.grammar).single.paper;
    final material = await store.saveExamMaterial(
      target: target,
      paper: paper,
      source: ExamSource.aiGenerated,
      model: 'Fixture',
      promptVersion: 1,
      id: 'objective',
    );
    final now = DateTime.now();
    final essay = await db
        .into(db.learningWritingTasks)
        .insertReturning(
          LearningWritingTasksCompanion.insert(
            id: 'essay',
            kind: WritingTaskKind.application.name,
            profile: profile.exam.id,
            level: SentenceLevel.beginner.name,
            topic: '',
            title: 'Request',
            prompt: 'Write a request.',
            model: 'Fixture',
            promptVersion: 1,
            createdAt: now,
          ),
        );
    final run = await store.startWrittenExam(
      profile: profile,
      objectives: [material],
      essays: [essay],
      now: now,
    );
    final id = run.row.id;
    await store.editWrittenSection(
      id: id,
      position: 0,
      answers: [paper.items.first.answers.first, '', '', '', ''],
      now: now.add(const Duration(seconds: 10)),
    );
    await store.selectWrittenSection(
      id,
      1,
      now: now.add(const Duration(seconds: 25)),
    );
    await store.editWrittenSection(
      id: id,
      position: 1,
      answers: ['Draft to restore.'],
      now: now.add(const Duration(seconds: 30)),
    );
    await store.markExamAiReviewed(material);
    store.dispose();
    await db.close();
    db = AppDatabase.file(file);
    store = LanguageLearningStore(db);
    final resumed = await store.writtenExam(id);
    expect(resumed.row.currentSection, 1);
    expect(resumed.sections.last.answers.single, 'Draft to restore.');
    expect(resumed.sections.first.row.seconds, 25);
    final afterDeadline = now.add(const Duration(minutes: 3));
    expect(resumed.remaining(afterDeadline), Duration.zero);
    await store.editWrittenSection(
      id: id,
      position: 1,
      answers: ['Too late'],
      now: afterDeadline,
    );
    final result = await store.submitWrittenExam(id, now: afterDeadline);
    expect(result.submitted, true);
    expect(result.row.submittedAt, resumed.row.deadline);
    expect(result.sections.last.row.seconds, 95);
    expect(result.sections.last.answers.single, 'Draft to restore.');
    expect(result.earnedHalfPoints, 3);
    expect(
      (await store.submitWrittenExam(id, now: afterDeadline)).earnedHalfPoints,
      3,
    );
    final attempt = await db.select(db.learningExamAttempts).getSingle();
    expect(attempt.reviewedAtSubmission, isFalse);
    expect(attempt.matched, 1);
    final snapshot = (await store.readLanguageProfile('en'))
        .skills[LanguageSkill.grammar]!;
    expect(snapshot.observations, hasLength(1));
    expect(snapshot.independent, 0);
  });
}
