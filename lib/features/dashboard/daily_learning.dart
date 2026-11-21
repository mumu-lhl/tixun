import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/l10n/app_strings.dart";
import "../progress/profile_editor.dart";
import "../review/review_providers.dart";

/// Whether [examDate] is already past, comparing calendar dates only.
/// Exam dates come from a date picker at midnight, so comparing against
/// the current time would mark the exam day itself as past from 00:00.
bool examDatePassed(DateTime examDate, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final examDay = DateTime(examDate.year, examDate.month, examDate.day);
  return examDay.isBefore(today);
}

class DailyLearning extends ConsumerWidget {
  const DailyLearning({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider),
        progress = ref.watch(progressProvider),
        profile = ref.watch(learningProfileProvider);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.whatToWorkOnToday,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            profile.when(
              data: (p) => TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProfileEditor(p),
                ),
                child: Text(context.l10n.learningSettings),
              ),
              loading: () => const SizedBox.shrink(),
              // Keep a retry here instead of hiding the button: the
              // editor needs the loaded profile, and opening it with
              // defaults could overwrite real settings on save.
              error: (_, _) => TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => ref.invalidate(learningProfileProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.l10n.retry),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: due.when(
            loading: () => Text(context.l10n.loadingReviewTasks),
            error: (_, _) => TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => ref.invalidate(dueCountProvider),
              child: Text(context.l10n.couldNotReadReviewTasks),
            ),
            data: (n) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n > 0
                      ? context.l10n.reviewsDue(l10nArgument((n)))
                      : context.l10n.noReviewsDue,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (n > 0) ...[
                  const SizedBox(height: 8),
                  Text(context.l10n.recallAndAnswerBeforeChecking),
                ],
                if (profile.value case final p?) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.todayMinutesStartWithMinutes(
                      l10nArgument((p.dailyMinutes)),
                      l10nArgument((p.dailyMinutes < 15 ? p.dailyMinutes : 15)),
                      l10nArgument(
                        (n > 0
                            ? context.l10n.dueReviewMaterial
                            : context.l10n.independentPractice),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (p.examDate != null)
                    Text(
                      examDatePassed(p.examDate!, DateTime.now())
                          ? context.l10n.theExamDateHasPassed
                          : context.l10n.examInDays(
                              l10nArgument(
                                (p.exam.isEmpty
                                    ? context.l10n.targetExam
                                    : p.exam),
                              ),
                              l10nArgument(
                                (p.examDate!.difference(DateTime.now()).inDays +
                                    1),
                              ),
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
                const SizedBox(height: 14),
                _DailyActions(hasReviews: n > 0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        progress.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.practiceRecordsAreTemporarilyUnavailable),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => ref.invalidate(progressProvider),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.total == 0
                    ? context.l10n.noPracticeRecords
                    : context.l10n.attemptsVerifiedRulesSelfAssessed(
                        l10nArgument((p.total)),
                        l10nArgument((p.checked)),
                        l10nArgument((p.self)),
                        l10nArgument((p.unverified)),
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (p.topics
                      .where((t) => t.questions >= 3 && t.correct < t.questions)
                      .firstOrNull
                  case final weak?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.l10n.suggestedFocus(
                      l10nArgument((context.subjectName(weak.subject))),
                      l10nArgument((weak.name)),
                      l10nArgument(
                        (context.l10n.independentAnswersCorrect(
                          l10nArgument((weak.correct)),
                          l10nArgument((weak.questions)),
                        )),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyActions extends StatelessWidget {
  const _DailyActions({required this.hasReviews});
  final bool hasReviews;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      key: const Key("today-review"),
      onPressed: () => context.go(hasReviews ? "/review" : "/practice"),
      icon: Icon(hasReviews ? Icons.event_repeat : Icons.edit_note, size: 18),
      label: Text(
        hasReviews ? context.l10n.startReview : context.l10n.startPractice,
      ),
    );
    final secondary = [
      TextButton(
        key: const Key("today-review-schedule"),
        onPressed: () => context.go("/review"),
        child: Text(context.l10n.reviewSchedule, textAlign: TextAlign.center),
      ),
      TextButton(
        key: const Key("today-learning-insights"),
        onPressed: () => context.go("/progress"),
        child: Text(context.l10n.learningInsights, textAlign: TextAlign.center),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 480) {
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [primary, ...secondary],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: secondary.first),
                const SizedBox(width: 8),
                Expanded(child: secondary.last),
              ],
            ),
          ],
        );
      },
    );
  }
}
