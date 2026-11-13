import '../library/study_localization.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../review/review_providers.dart';
import '../review/review_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(progressProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(progressProvider),
            child: Text(context.l10n.couldNotReadRecordsTap),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/study'),
                icon: const Icon(Icons.arrow_back),
                label: Text(context.l10n.backToStudy),
              ),
            ),
            Text(
              context.l10n.learningInsights,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.basedOnlyOnRealRecords),
            const SizedBox(height: 20),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _metric(context, context.l10n.completedAttempts, '${p.total}'),
                _metric(
                  context,
                  context.l10n.gradingAgainstVerifiedAnswers,
                  '${p.checked}',
                ),
                _metric(context, context.l10n.selfAssessed, '${p.self}'),
                _metric(
                  context,
                  context.l10n.uncheckedAIReferenceGrading,
                  '${p.unverified}',
                ),
                _metric(context, context.l10n.hintUsed, '${p.hinted}'),
              ],
            ),
            const Divider(height: 40),
            Text(
              context.l10n.knowledgePointEvidence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.onlyTheLatestGradedAttempt,
              style: TextStyle(fontSize: 12),
            ),
            if (p.topics.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(context.l10n.notEnoughIndependentEvidenceYet),
              ),
            for (final t in p.topics)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${context.subjectName(t.subject)} · ${t.name}'),
                subtitle: Text(
                  t.questions < 3
                      ? context.l10n.notEnoughEvidenceDistinctQuestions(
                          l10nArgument((t.questions)),
                        )
                      : context.l10n.independentAnswersCorrect(
                          l10nArgument((t.correct)),
                          l10nArgument((t.questions)),
                        ),
                ),
                trailing: t.questions >= 3 && t.correct < t.questions
                    ? const Icon(Icons.priority_high)
                    : null,
              ),
            const Divider(height: 32),
            Text(
              context.l10n.recordedErrorCauses,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (p.errorReasons.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.l10n.noConfirmedErrorCausesYet),
              ),
            for (final e in p.errorReasons.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(mistakeReasonLabel(context, e.key)),
                trailing: Text(
                  context.l10n.mistakeCount(l10nArgument((e.value))),
                ),
              ),
            const Divider(height: 32),
            Text(
              context.l10n.recentPractice,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (p.recent.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.l10n.yourActualRecordsWillAppear),
              ),
            for (final a in p.recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  a.stem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${l10nArgument(reviewDate(a.time, context: context))} · ${l10nArgument(a.basis == 'self'
                      ? context.l10n.selfAssessed
                      : a.basis == 'ai_reference'
                      ? context.l10n.aiReferenceNeedsChecking
                      : context.l10n.ruleBasedGrading)}${l10nArgument(a.hint ? context.l10n.hintUsedSuffix : '')}',
                ),
                trailing: Text(
                  a.correct
                      ? context.l10n.correct
                      : context.l10n.correctionRequired,
                ),
              ),
          ],
        ),
      );
  Widget _metric(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: colors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
