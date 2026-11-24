import "language_profile_store.dart";
import "language_skills.dart";
import "sentence_store.dart";
import "language_store.dart";
import "sentence_batch_store.dart";
import "sentence_content.dart";

typedef SentencePerformance = ({
  int correct,
  int checked,
  int assisted,
  int selfRated,
  DateTime? lastPracticed,
});

class SentencePlan {
  const SentencePlan({
    required this.skill,
    required this.performance,
    required this.count,
    required this.level,
    required this.style,
    required this.exclusions,
    required this.diagnostic,
  });

  final SentenceSkill skill;
  final SentencePerformance performance;
  final int count;
  final SentenceLevel level;
  final SentenceStyle style;
  final List<String> exclusions;

  final bool diagnostic;
}

/// Uses the same evidence and selection policy as the profile page, restricted
/// to skills this practice screen can deliver.
Future<SentencePlan> suggestSentences(LanguageLearningStore store) async {
  final profile = await store.readLanguageProfile("en");
  final recommendation = recommendLanguage(
    profile,
    LanguageGoal.communication,
    restrictTo: {
      for (final skill in SentenceSkill.values) sentenceAbility(skill),
    },
  );
  final recent = await store.sentenceEvidence("en").first;
  return sentencePlan(
    profile,
    recommendation,
    recent.map((row) => row.sentence),
  );
}

SentencePlan sentencePlan(
  LanguageProfile profile,
  LanguageRecommendation recommendation,
  Iterable<String> exclusions,
) {
  final skill = SentenceSkill.values.firstWhere(
    (skill) => sentenceAbility(skill) == recommendation.skill,
  );
  final row = profile.skills[recommendation.skill]!;
  return SentencePlan(
    skill: skill,
    diagnostic: recommendation.diagnostic,
    count: recommendation.count,
    level: recommendation.level,
    style: skill == SentenceSkill.intention
        ? SentenceStyle.dialogue
        : SentenceStyle.written,
    exclusions: exclusions.toSet().take(40).toList(),
    performance: (
      correct: row.correct,
      checked: row.independent,
      assisted: row.count(EvidenceKind.assisted),
      selfRated: row.count(EvidenceKind.selfReport),
      lastPracticed: row.latest,
    ),
  );
}

extension SentencePlanStore on LanguageLearningStore {
  Future<List<SentenceCard>> savedForSentencePlan(SentencePlan plan) async {
    final rows = await savedSentenceBatches();
    final seen = plan.exclusions.map(normalizeLanguageText).toSet();
    return [
      for (final row in rows)
        if (row.style == plan.style.name)
          for (final card in openSavedSentenceBatch(row).cards)
            if (card.skill == plan.skill &&
                card.level == plan.level &&
                card.choices.isNotEmpty &&
                seen.add(normalizeLanguageText(card.text)))
              card,
    ].take(plan.count).toList();
  }
}
