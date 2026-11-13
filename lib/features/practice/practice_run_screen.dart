import 'package:tixun/core/l10n/app_error_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';
import 'practice_run.dart';
import 'question_card.dart';

final practiceRunProvider = FutureProvider<PracticeRun?>(
  (ref) => ref.watch(practiceStoreProvider).loadRun(),
);
final runAttemptsProvider = FutureProvider.autoDispose
    .family<List<PracticeAttempt>, String>((ref, key) {
      final db = ref.watch(practiceStoreProvider).db;
      return (db.select(
        db.practiceAttempts,
      )..where((a) => a.id.isIn(key.split('|')))).get();
    });

class PracticeRunScreen extends ConsumerWidget {
  const PracticeRunScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(practiceRunProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is FormatException
                      ? failureText(context.l10n, e)
                      : context.l10n.couldNotLoadTheQuiz,
                ),
                TextButton(
                  onPressed: () => act(context, () async {
                    await ref.read(practiceStoreProvider).clearRun();
                    if (context.mounted) context.go('/practice');
                  }),
                  child: Text(context.l10n.endThisQuizKeepRecords),
                ),
              ],
            ),
          ),
        ),
        data: (run) {
          if (run == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.noQuizInProgressYet,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/practice'),
                      child: Text(context.l10n.returnToTheBankTo),
                    ),
                  ],
                ),
              ),
            );
          }
          final store = ref.read(practiceStoreProvider);
          final graded =
              run.completed ||
              ref
                      .watch(runAttemptsProvider(run.attempts[run.index]!))
                      .value
                      ?.singleOrNull
                      ?.status ==
                  'graded';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/practice'),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(context.l10n.backToQuestionBank),
                  ),
                  Text(
                    run.completed
                        ? context.l10n.quizCompleted
                        : context.l10n.randomQuizQuestion(
                            l10nArgument((run.index + 1)),
                            l10nArgument((run.ids.length)),
                          ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => act(context, () async {
                      await store.clearRun();
                      if (context.mounted) context.go('/practice');
                    }),
                    child: Text(context.l10n.endQuiz),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!run.completed) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: QuestionCard(
                      run.ids[run.index],
                      attemptId: run.attempts[run.index],
                      key: ValueKey(run.attempts[run.index]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        key: const Key('next-run-question'),
                        onPressed: !graded
                            ? null
                            : () => act(context, () async {
                                await store.advanceRun(
                                  expectedAttemptId: run.attempts[run.index],
                                );
                              }),
                        child: Text(
                          run.index + 1 == run.ids.length
                              ? context.l10n.finishQuiz
                              : context.l10n.nextQuestion,
                        ),
                      ),
                      if (!graded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.l10n.youCanContinueToThe,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else
                ref
                    .watch(
                      runAttemptsProvider(
                        run.attempts.whereType<String>().join('|'),
                      ),
                    )
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) =>
                          Text(context.l10n.couldNotLoadTheSummary),
                      data: (attempts) {
                        final colors = Theme.of(context).colorScheme;
                        final byId = {for (final a in attempts) a.id: a};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.attemptsSaved(
                                l10nArgument((attempts.length)),
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.matchedReferenceHintsUsed(
                                l10nArgument(
                                  (attempts
                                      .where((a) => a.correct == true)
                                      .length),
                                ),
                                l10nArgument(
                                  (attempts.where((a) => a.hintUsed).length),
                                ),
                              ),
                            ),
                            Text(
                              context.l10n.attemptsUsedUncheckedAIReferences(
                                l10nArgument(
                                  (attempts
                                      .where(
                                        (a) => a.gradingBasis == 'ai_reference',
                                      )
                                      .length),
                                ),
                                l10nArgument(
                                  (attempts
                                      .where((a) => a.gradingBasis == 'self')
                                      .length),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(run.ids.length, (i) {
                              final attemptId = run.attempts[i];
                              final attempt = attemptId == null
                                  ? null
                                  : byId[attemptId];
                              final outcome = attempt == null
                                  ? null
                                  : attempt.status == 'graded'
                                  ? (attempt.correct == true
                                        ? 'correct'
                                        : 'wrong')
                                  : 'pending';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  outcome == 'correct'
                                      ? Icons.check_circle
                                      : outcome == 'wrong'
                                      ? Icons.cancel
                                      : Icons.help_outline,
                                  color: outcome == 'correct'
                                      ? colors.primary
                                      : outcome == 'wrong'
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                                ),
                                title: Text(
                                  context.l10n.viewQuestionFromThisQuiz(
                                    l10nArgument((i + 1)),
                                  ),
                                ),
                                subtitle: outcome == null
                                    ? null
                                    : Text(
                                        outcome == 'correct'
                                            ? context.l10n.answerCorrect
                                            : outcome == 'wrong'
                                            ? context.l10n.needsCorrection
                                            : context.l10n.notGradedYet,
                                      ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go(
                                  '/practice/${run.ids[i]}?attempt=${run.attempts[i]}',
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ],
          );
        },
      );
}
