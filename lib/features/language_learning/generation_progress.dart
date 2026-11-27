import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

import "../../core/l10n/app_strings.dart";
import "generation_activity.dart";

class LanguageGenerationActivity extends StatelessWidget {
  const LanguageGenerationActivity({
    super.key,
    required this.activity,
    this.completed,
    this.total,
  });
  final ValueListenable<GenerationActivity?> activity;
  final int? completed;
  final int? total;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<GenerationActivity?>(
        valueListenable: activity,
        builder: (context, current, _) {
          if (current == null) {
            return LanguageGenerationProgress(
              label: context.l10n.languageGenerationPreparing,
            );
          }
          final l10n = context.l10n;
          final subject = switch (current.feature) {
            "language_vocabulary" ||
            "language_vocabulary_revision" => l10n.languageGenerationVocabulary,
            "language_sentence_batch" ||
            "language_context_understanding" ||
            "language_sentence_check" => l10n.languageGenerationSentences,
            "language_exam_generation" => l10n.languageGenerationExam,
            "language_exam_review" => l10n.languageGenerationExamReview,
            "language_writing_task" => l10n.languageGenerationWritingTask,
            "language_writing" => l10n.languageGenerationWritingFeedback,
            "language_explanation" => l10n.languageGenerationExplanation,
            "language_quick_lookup" => l10n.languageGenerationLookup,
            _ => l10n.languageGenerationContent,
          };
          final label = switch (current.phase) {
            GenerationPhase.generating =>
              current.feature == "language_exam_review"
                  ? l10n.languageGenerationReviewingExam
                  : l10n.languageGenerationGenerating(subject),
            GenerationPhase.validating => l10n.languageGenerationValidating(
              subject,
            ),
            GenerationPhase.saving => l10n.languageGenerationSaving,
            GenerationPhase.comparing => l10n.languageGenerationComparing,
          };
          return LanguageGenerationProgress(
            label: label,
            completed: current.phase == GenerationPhase.comparing
                ? null
                : completed ??
                      current.completed ??
                      (current.total == null ? null : 0),
            total: current.phase == GenerationPhase.comparing
                ? null
                : total ?? current.total,
          );
        },
      );
}

/// Counts only items accepted by the generating operation's validation.
class LanguageGenerationProgress extends StatelessWidget {
  const LanguageGenerationProgress({
    super.key,
    required this.label,
    this.completed,
    this.total,
  });

  final String label;
  final int? completed;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final count = completed;
    final target = total;
    final value = count != null && target != null && target > 0
        ? (count / target).clamp(0.0, 1.0)
        : null;
    final text = value == null
        ? label
        : context.l10n.languageGenerationCount(
            label,
            count!,
            target!,
            (value * 100).floor(),
          );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      liveRegion: true,
      label: text,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: AnimatedSwitcher(
              duration: duration,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: Text(text, key: ValueKey(text)),
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: TickerMode(
              enabled: !MediaQuery.disableAnimationsOf(context),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: value ?? 0, end: value ?? 0),
                duration: duration,
                builder: (context, animated, _) => LinearProgressIndicator(
                  value: value == null ? null : animated,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
