import "package:flutter_test/flutter_test.dart";
import "package:tixun/features/language_learning/exam_material.dart";
import "package:tixun/features/language_learning/language_skills.dart";
import "package:tixun/features/language_learning/sentence_content.dart";

void main() {
  final now = DateTime.now();
  LanguageProfile profile(List<LanguageObservation> evidence) =>
      LanguageProfile(
        language: "en",
        exam: ExamProfile.zhejiang2026,
        due: 0,
        evidence: evidence,
      );
  LanguageObservation answer(
    int n, {
    bool correct = true,
    EvidenceKind kind = EvidenceKind.independent,
    SentenceLevel? level = SentenceLevel.beginner,
    String? id,
    int daysAgo = 0,
  }) => LanguageObservation(
    id: id ?? "item-$n",
    skill: LanguageSkill.condition,
    kind: kind,
    verified: false,
    correct: correct,
    level: level,
    at: now.subtract(Duration(days: daysAgo, minutes: n)),
    basis: "item $n",
  );
  LanguageRecommendation next(
    List<LanguageObservation> evidence, {
    SentenceLevel? difficulty,
  }) => recommendLanguage(
    profile(evidence),
    LanguageGoal.communication,
    restrictTo: {LanguageSkill.condition},
    difficulty: difficulty,
  );

  test(
    "fresh unaided successes allow a challenge without confirming mastery",
    () {
      final evidence = [for (var n = 0; n < 3; n++) answer(n)];
      final recommendation = next(evidence);
      expect(recommendation.level, SentenceLevel.intermediate);
      expect(recommendation.diagnostic, isFalse);
      expect(recommendation.count, 5);
      expect(
        profile(evidence).skills[LanguageSkill.condition]!.uncertain,
        isTrue,
      );
      expect(profile(evidence).skills[LanguageSkill.condition]!.independent, 0);
    },
  );

  test(
    "help, repeats, one material, unknown level and old work do not promote",
    () {
      for (final evidence in [
        <LanguageObservation>[],
        [answer(0)],
        [for (var n = 0; n < 4; n++) answer(n, kind: EvidenceKind.assisted)],
        [for (var n = 0; n < 4; n++) answer(n, kind: EvidenceKind.repeat)],
        [for (var n = 0; n < 4; n++) answer(n, kind: EvidenceKind.selfReport)],
        [for (var n = 0; n < 4; n++) answer(n, kind: EvidenceKind.unverified)],
        [for (var n = 0; n < 4; n++) answer(n, id: "one-paper")],
        [for (var n = 0; n < 4; n++) answer(n, level: null)],
        [for (var n = 0; n < 4; n++) answer(n, daysAgo: 40)],
      ]) {
        expect(next(evidence).level, SentenceLevel.beginner);
        expect(next(evidence).diagnostic, isTrue);
      }
    },
  );

  test("question count cannot replace independent practice samples", () {
    final onePaper = [for (var n = 0; n < 20; n++) answer(n, id: "paper")];
    expect(next(onePaper).diagnostic, isTrue);
    final threePapers = [
      for (var paper = 0; paper < 3; paper++)
        for (var n = 0; n < 10; n++) answer(paper * 10 + n, id: "paper-$paper"),
    ];
    expect(next(threePapers).diagnostic, isFalse);
    expect(next(threePapers).level, SentenceLevel.intermediate);
    // A long successful paper cannot drown out two unsuccessful papers.
    expect(
      next([
        ...onePaper,
        answer(21, correct: false, id: "second"),
        answer(22, correct: false, id: "third"),
      ]).level,
      SentenceLevel.beginner,
    );
  });

  test("challenge backs off on fresh failures, not one wrong answer", () {
    expect(
      next([answer(0, correct: false, level: SentenceLevel.intermediate)])
          .level,
      SentenceLevel.intermediate,
    );
    final evidence = [
      for (var n = 0; n < 3; n++)
        answer(n, correct: false, level: SentenceLevel.intermediate),
    ];
    expect(next(evidence).level, SentenceLevel.beginner);
    expect(
      next(evidence, difficulty: SentenceLevel.intermediate).level,
      SentenceLevel.intermediate,
    );
  });

  test(
    "a level change starts a new check rather than recycling earlier successes",
    () {
      expect(
        next([
          answer(0),
          answer(1, correct: false, level: SentenceLevel.intermediate),
          answer(2),
          answer(3),
          answer(4),
        ]).level,
        SentenceLevel.beginner,
      );
    },
  );
}
