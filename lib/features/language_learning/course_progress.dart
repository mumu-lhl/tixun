import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'course_content.dart';
import 'language_store.dart';

const courseReviewInterval = Duration(days: 7);

String courseLessonId(int index) => 'course-v1-$index';

class CourseProgress {
  const CourseProgress(this.attempts);
  final List<LearningCourseAttempt> attempts;

  Set<int> get passedRotations => {
    for (final attempt in attempts)
      if (attempt.recognized == 2 && attempt.produced == 1) attempt.rotation,
  };
  bool get passed => passedRotations.length >= 2;
  DateTime? get lastSuccess => attempts
      .where((a) => a.recognized == 2 && a.produced == 1)
      .firstOrNull
      ?.occurredAt;
  bool due(DateTime now) =>
      passed && lastSuccess!.add(courseReviewInterval).isBefore(now);
  int get nextRotation {
    for (var offset = 0; offset < 3; offset++) {
      final rotation = (attempts.length + offset) % 3;
      if (!passedRotations.contains(rotation)) return rotation;
    }
    return attempts.length % 3;
  }
}

List<LanguageLesson> languageLessons(String language) => switch (language) {
  'en' => englishLessons,
  'ja' => japaneseLessons,
  _ => const [],
};

bool sameCourseExpression(String response, String expected) {
  String canonical(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'''[\s.,;:!?'"、。！？・！，．]'''), '');
  return canonical(response).isNotEmpty &&
      canonical(response) == canonical(expected);
}

extension CourseProgressStore on LanguageLearningStore {
  Stream<Map<String, CourseProgress>> courseProgress(String language) =>
      (db.select(db.learningCourseAttempts)
            ..where((row) => row.language.equals(language))
            ..orderBy([
              (row) => OrderingTerm.desc(row.occurredAt),
              (row) => OrderingTerm.desc(row.rowId),
            ]))
          .watch()
          .map((rows) {
            final grouped = <String, List<LearningCourseAttempt>>{};
            for (final row in rows) {
              (grouped[row.lesson] ??= []).add(row);
            }
            return grouped.map(
              (id, rows) => MapEntry(id, CourseProgress(rows)),
            );
          });

  Future<void> recordCourseCheck({
    required String language,
    required int lesson,
    required int rotation,
    required int recognized,
    required int produced,
    String? id,
    DateTime? now,
  }) => runOperation(() async {
    if (lesson < 0 ||
        lesson >= languageLessons(language).length ||
        rotation < 0 ||
        rotation >= 3 ||
        recognized < 0 ||
        recognized > 2 ||
        produced < 0 ||
        produced > 1) {
      throw const FormatException('Invalid course check');
    }
    await db
        .into(db.learningCourseAttempts)
        .insert(
          LearningCourseAttemptsCompanion.insert(
            id: id ?? const Uuid().v4(),
            language: language,
            lesson: courseLessonId(lesson),
            rotation: rotation,
            recognized: recognized,
            produced: produced,
            occurredAt: now ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    changed();
  });
}
