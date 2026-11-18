import '../../core/database/database.dart';
import 'sentence_content.dart';

typedef SuggestedSentences = ({
  SentenceSkill skill,
  int correct,
  int checked,
  SentenceBatch batch,
});

/// Input is the recent history, newest first. One independently answered
/// answer per sentence contributes; repeated guesses and self-ratings don't.
SuggestedSentences? suggestSentences(List<LearningSentenceAttempt> recent) {
  final counted = <String>{};
  final scores = <SentenceSkill, ({int correct, int checked})>{};
  for (final attempt in recent) {
    final correct = attempt.correct;
    if (correct == null ||
        attempt.helpBeforeAnswer != 0 ||
        !counted.add(attempt.sentenceId)) {
      continue;
    }
    final skill = SentenceSkill.values.asNameMap()[attempt.skill];
    if (skill == null) continue;
    final previous = scores[skill] ?? (correct: 0, checked: 0);
    scores[skill] = (
      correct: previous.correct + (correct ? 1 : 0),
      checked: previous.checked + 1,
    );
  }

  final seen = recent.map((attempt) => attempt.sentenceId).toSet();
  final candidates =
      scores.entries.where((entry) {
        final score = entry.value;
        return score.checked >= 2 && score.correct * 2 <= score.checked;
      }).toList()..sort((a, b) {
        final rate = (a.value.correct * b.value.checked).compareTo(
          b.value.correct * a.value.checked,
        );
        return rate != 0 ? rate : b.value.checked.compareTo(a.value.checked);
      });
  for (final entry in candidates) {
    final fresh = followUpSentences.where(
      (card) => card.skill == entry.key && !seen.contains(card.id),
    );
    if (fresh.isNotEmpty) {
      return (
        skill: entry.key,
        correct: entry.value.correct,
        checked: entry.value.checked,
        batch: SentenceBatch(fresh.take(2)),
      );
    }
  }
  return null;
}
