import 'exam_material.dart';
import 'writing_task_ai.dart';

/// Written practice scope of the 2026 Zhejiang exam. The application chooses
/// its own practice duration because it cannot administer the listening section.
class WrittenExamProfile {
  const WrittenExamProfile({
    required this.id,
    required this.region,
    required this.year,
    required this.exam,
    required this.duration,
    required this.sections,
  });

  final String id, region;
  final int year;
  final ExamProfile exam;
  final Duration duration;
  final List<WrittenSectionSpec> sections;

  int get maximumHalfPoints =>
      sections.fold(0, (sum, section) => sum + section.maximumHalfPoints);
  int get objectiveHalfPoints => sections
      .where((section) => section.kind != null)
      .fold(0, (sum, section) => sum + section.maximumHalfPoints);

  static const zhejiang2026 = WrittenExamProfile(
    id: 'zhejiang-gaokao-en-2026-written-v1',
    region: 'Zhejiang',
    year: 2026,
    exam: ExamProfile.zhejiang2026,
    duration: Duration(minutes: 100),
    sections: [
      WrittenSectionSpec.objective(ExamKind.reading, 3, 5),
      WrittenSectionSpec.objective(ExamKind.reading, 4, 5),
      WrittenSectionSpec.objective(ExamKind.reading, 4, 5),
      WrittenSectionSpec.objective(ExamKind.reading, 4, 5),
      WrittenSectionSpec.objective(ExamKind.sentenceInsertion, 5, 5),
      WrittenSectionSpec.objective(ExamKind.cloze, 15, 2),
      WrittenSectionSpec.objective(ExamKind.grammar, 10, 3),
      WrittenSectionSpec.writing(WritingTaskKind.application, 30),
      WrittenSectionSpec.writing(WritingTaskKind.continuation, 50),
    ],
  );
}

class WrittenSectionSpec {
  const WrittenSectionSpec.objective(this.kind, this.count, this.halfPoints)
    : writing = null;
  const WrittenSectionSpec.writing(this.writing, this.halfPoints)
    : kind = null,
      count = 1;

  final ExamKind? kind;
  final WritingTaskKind? writing;
  final int count, halfPoints;
  int get maximumHalfPoints => count * halfPoints;
}
