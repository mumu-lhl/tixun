import "../../core/database/database.dart";
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
  });

  final SentenceSkill skill;
  final SentencePerformance performance;
  final int count;
  final SentenceLevel level;
  final SentenceStyle style;
  final List<String> exclusions;

  bool get diagnostic => performance.checked < 2;
}

/// Only distinct unassisted checks affect the strength estimate. Self-ratings
/// and assisted checks remain visible evidence with separate counts.
SentencePlan suggestSentences(List<LearningSentenceAttempt> recent) {
  final evidence = {
    for (final skill in SentenceSkill.values)
      skill: (
        correct: 0,
        checked: 0,
        assisted: 0,
        selfRated: 0,
        lastPracticed: null as DateTime?,
      ),
  };
  final seenIndependent = <(SentenceSkill, String)>{};
  final seenAssisted = <(SentenceSkill, String)>{};
  final moreRecent = <SentenceSkill>[];
  for (final attempt in recent) {
    final skill = SentenceSkill.values.asNameMap()[attempt.skill];
    if (skill == null) continue;
    final previous = evidence[skill]!;
    final key = (skill, normalizeLanguageText(attempt.sentence));
    final correct = attempt.correct;
    final independent = correct != null && attempt.helpBeforeAnswer == 0;
    final newCheck = independent && seenIndependent.add(key);
    final newAssisted =
        correct != null && !independent && seenAssisted.add(key);
    if (newCheck) moreRecent.add(skill);
    evidence[skill] = (
      correct: previous.correct + (newCheck && correct == true ? 1 : 0),
      checked: previous.checked + (newCheck ? 1 : 0),
      assisted: previous.assisted + (newAssisted ? 1 : 0),
      selfRated: previous.selfRated + (correct == null ? 1 : 0),
      lastPracticed: previous.lastPracticed ?? attempt.occurredAt,
    );
  }
  // Rotate after an intensive recent set so one weak skill does not consume
  // every suggestion. An estimate with two samples still has low confidence.
  final recentSet = moreRecent.take(3).toList();
  final candidates = SentenceSkill.values
      .where(
        (skill) =>
            recentSet.length < 3 ||
            recentSet.where((s) => s == skill).length < 2,
      )
      .toList();
  final weak =
      candidates.where((skill) {
        final row = evidence[skill]!;
        return row.checked >= 2 && row.correct * 2 <= row.checked;
      }).toList()..sort((a, b) {
        final lhs = evidence[a]!, rhs = evidence[b]!;
        return ((lhs.correct + 1) / (lhs.checked + 2)).compareTo(
          (rhs.correct + 1) / (rhs.checked + 2),
        );
      });
  candidates.sort((a, b) {
    final lhs = evidence[a]!, rhs = evidence[b]!;
    final sampleOrder = lhs.checked.compareTo(rhs.checked);
    if (sampleOrder != 0) return sampleOrder;
    return (lhs.lastPracticed?.millisecondsSinceEpoch ?? 0).compareTo(
      rhs.lastPracticed?.millisecondsSinceEpoch ?? 0,
    );
  });
  final skill = weak.firstOrNull ?? candidates.first;
  final performance = evidence[skill]!;
  return SentencePlan(
    skill: skill,
    performance: performance,
    count: performance.checked < 2 ? 3 : 5,
    level:
        performance.checked < 2 ||
            performance.correct * 2 <= performance.checked
        ? SentenceLevel.beginner
        : SentenceLevel.intermediate,
    style: skill == SentenceSkill.intention
        ? SentenceStyle.dialogue
        : SentenceStyle.written,
    exclusions: recent
        .map((attempt) => attempt.sentence)
        .toSet()
        .take(40)
        .toList(),
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
