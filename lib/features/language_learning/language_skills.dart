import 'exam_material.dart';
import 'sentence_content.dart';

/// Names are stable IDs used by projections, distinct from translated labels.
enum LanguageSkill {
  wordRecognition,
  wordRecall,
  formRecognition,
  formProduction,
  collocation,
  wordApplication,
  sequence,
  condition,
  reference,
  structure,
  intention,
  cause,
  detail,
  mainIdea,
  inference,
  cohesion,
  reading,
  insertion,
  cloze,
  grammar,
  writingTask,
  writingOrganization,
  writingAccuracy,
}

LanguageSkill sentenceAbility(SentenceSkill skill) => switch (skill) {
  SentenceSkill.sequence => LanguageSkill.sequence,
  SentenceSkill.condition => LanguageSkill.condition,
  SentenceSkill.reference => LanguageSkill.reference,
  SentenceSkill.structure => LanguageSkill.structure,
  SentenceSkill.intention => LanguageSkill.intention,
  SentenceSkill.cause => LanguageSkill.cause,
  SentenceSkill.detail => LanguageSkill.detail,
  SentenceSkill.collocation => LanguageSkill.collocation,
  SentenceSkill.discourse => LanguageSkill.cohesion,
  SentenceSkill.mainIdea => LanguageSkill.mainIdea,
  SentenceSkill.inference => LanguageSkill.inference,
};

LanguageSkill examAbility(ExamKind kind) => switch (kind) {
  ExamKind.reading => LanguageSkill.reading,
  ExamKind.sentenceInsertion => LanguageSkill.insertion,
  ExamKind.cloze => LanguageSkill.cloze,
  ExamKind.grammar => LanguageSkill.grammar,
};

enum EvidenceKind {
  independent,
  assisted,
  repeat,
  selfReport,
  unverified,
  disputed,
}

class LanguageObservation {
  const LanguageObservation({
    required this.id,
    required this.skill,
    required this.kind,
    required this.at,
    required this.basis,
    this.correct,
    this.profile,
    this.verified = true,
  });

  final String id, basis;
  final LanguageSkill skill;
  final EvidenceKind kind;
  final DateTime at;
  final bool? correct;
  final bool verified;
  final ExamProfile? profile;
}

class SkillPerformance {
  SkillPerformance(this.skill, Iterable<LanguageObservation> observations)
    : observations = List.unmodifiable(observations);

  final LanguageSkill skill;
  final List<LanguageObservation> observations;
  int count(EvidenceKind kind) =>
      observations.where((row) => row.kind == kind).length;
  int get independent => observations
      .where((row) => row.kind == EvidenceKind.independent && row.verified)
      .length;
  int get tentative => observations
      .where((row) => row.kind == EvidenceKind.independent && !row.verified)
      .length;
  bool get preliminaryWeak {
    final samples = <String, List<bool>>{};
    for (final row in observations) {
      if (row.verified || row.correct == null) continue;
      if (row.kind == EvidenceKind.independent) {
        (samples[row.id] ??= []).add(row.correct!);
      } else if (row.kind == EvidenceKind.unverified) {
        samples.putIfAbsent(row.id, () => [row.correct!]);
      }
    }
    final weak = samples.values
        .where(
          (group) => group.where((value) => value).length * 2 <= group.length,
        )
        .length;
    return samples.length >= 2 && weak * 2 >= samples.length;
  }

  int get correct => observations
      .where(
        (row) =>
            row.kind == EvidenceKind.independent &&
            row.verified &&
            row.correct == true,
      )
      .length;
  int get correctAssisted => observations
      .where((row) => row.kind == EvidenceKind.assisted && row.correct == true)
      .length;
  DateTime? get latest => observations.firstOrNull?.at;
  bool get uncertain =>
      independent < 3 ||
      observations
              .where(
                (row) => row.kind == EvidenceKind.independent && row.verified,
              )
              .map((row) => row.id)
              .toSet()
              .length <
          2;
  bool get weak => !uncertain && correct * 2 <= independent;
}

class LanguageProfile {
  LanguageProfile({
    required this.language,
    required this.exam,
    required this.due,
    required Iterable<LanguageObservation> evidence,
    this.hasApplications = true,
    this.hasForms = true,
  }) {
    final scope =
        evidence
            .where((row) => row.profile == null || row.profile == exam)
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    skills = {
      for (final skill in LanguageSkill.values)
        skill: SkillPerformance(
          skill,
          scope.where((row) => row.skill == skill),
        ),
    };
  }

  final String language;
  final ExamProfile exam;
  final int due;
  final bool hasApplications, hasForms;
  late final Map<LanguageSkill, SkillPerformance> skills;
}

enum LanguageGoal { communication, exam, foundations }

typedef LanguageRecommendation = ({
  LanguageSkill skill,
  SentenceLevel level,
  int count,
  bool diagnostic,
});

LanguageRecommendation recommendLanguage(
  LanguageProfile profile,
  LanguageGoal goal, {
  SentenceLevel? difficulty,
  Set<LanguageSkill> skip = const {},
}) {
  final allowed = switch (goal) {
    LanguageGoal.communication => [
      LanguageSkill.wordApplication,
      LanguageSkill.sequence,
      LanguageSkill.condition,
      LanguageSkill.reference,
      LanguageSkill.structure,
      LanguageSkill.intention,
      LanguageSkill.cause,
      LanguageSkill.detail,
      LanguageSkill.collocation,
      LanguageSkill.cohesion,
      LanguageSkill.mainIdea,
      LanguageSkill.formRecognition,
      LanguageSkill.formProduction,
    ],
    LanguageGoal.exam => [
      LanguageSkill.reading,
      LanguageSkill.insertion,
      LanguageSkill.cloze,
      LanguageSkill.grammar,
      LanguageSkill.writingTask,
      LanguageSkill.inference,
    ],
    LanguageGoal.foundations => [
      LanguageSkill.wordRecognition,
      LanguageSkill.wordRecall,
      LanguageSkill.structure,
      LanguageSkill.sequence,
      LanguageSkill.condition,
    ],
  };
  final available = allowed
      .where(
        (skill) => switch (skill) {
          LanguageSkill.wordApplication => profile.hasApplications,
          LanguageSkill.formRecognition ||
          LanguageSkill.formProduction => profile.hasForms,
          _ => true,
        },
      )
      .toList();
  final options = available.where((skill) => !skip.contains(skill)).toList();
  final candidates = options.isEmpty ? available : options;
  final latest = [
    for (final skill in candidates)
      ...profile.skills[skill]!.observations.take(3),
  ]..sort((a, b) => b.at.compareTo(a.at));
  final frequent = latest.take(3).map((row) => row.skill).toList();
  int priority(LanguageSkill skill) {
    final row = profile.skills[skill]!;
    final repetition = frequent.where((value) => value == skill).length;
    final base = row.weak
        ? 0
        : row.preliminaryWeak
        ? 1
        : row.uncertain
        ? 2
        : 4;
    final needsContext =
        goal == LanguageGoal.communication &&
        {
          LanguageSkill.cohesion,
          LanguageSkill.mainIdea,
          LanguageSkill.inference,
        }.contains(skill) &&
        profile.skills[LanguageSkill.structure]!.observations.isEmpty &&
        profile.skills[LanguageSkill.detail]!.observations.isEmpty;
    return base + (repetition >= 2 ? 5 : repetition) + (needsContext ? 2 : 0);
  }

  candidates.sort((a, b) {
    final result = priority(a).compareTo(priority(b));
    if (result != 0) return result;
    final aTime = profile.skills[a]!.latest?.millisecondsSinceEpoch ?? 0;
    final bTime = profile.skills[b]!.latest?.millisecondsSinceEpoch ?? 0;
    final time = aTime.compareTo(bTime);
    return time == 0 ? allowed.indexOf(a).compareTo(allowed.indexOf(b)) : time;
  });
  final skill = candidates.first;
  final row = profile.skills[skill]!;
  return (
    skill: skill,
    level:
        difficulty ??
        (row.uncertain || row.weak
            ? SentenceLevel.beginner
            : SentenceLevel.intermediate),
    count: row.uncertain ? 3 : 5,
    diagnostic: row.uncertain,
  );
}
