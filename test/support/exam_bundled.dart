import "package:tixun/features/language_learning/exam_material.dart";

import "gap_exercises.dart";
import "reading_content.dart";

import "package:tixun/features/language_learning/sentence_content.dart";

List<({String id, ExamPaper paper})> bundledExamPapers(ExamKind kind) {
  final passages = switch (kind) {
    ExamKind.reading => readingPassages,
    ExamKind.sentenceInsertion => sentenceInsertionPassages,
    ExamKind.cloze => clozePassages,
    ExamKind.grammar => grammarGapPassages,
  };
  return [
    for (final passage in passages)
      (
        id: "bundled:${passage.id}:v1",
        paper: ExamPaper(
          title: passage.title,
          paragraphs: passage.paragraphs,
          candidates: kind == ExamKind.sentenceInsertion
              ? passage.items.first.options
              : const {},
          items: [
            for (final item in passage.items)
              ExamItem(
                prompt: item.question,
                answers: item.acceptedAnswers,
                options: kind == ExamKind.sentenceInsertion
                    ? const {}
                    : item.options,
                skill: switch (kind) {
                  ExamKind.reading => SentenceSkill.detail,
                  ExamKind.sentenceInsertion => SentenceSkill.discourse,
                  ExamKind.cloze => SentenceSkill.collocation,
                  ExamKind.grammar => SentenceSkill.structure,
                },
                evidence: passage.paragraphs[item.evidence],
                explanation: item.explanation,
                distractors: const {},
              ),
          ],
        ),
      ),
  ];
}
