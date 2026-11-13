import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';

class PracticeHistoryScreen extends ConsumerStatefulWidget {
  const PracticeHistoryScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<PracticeHistoryScreen> createState() =>
      _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends ConsumerState<PracticeHistoryScreen> {
  final rows = <PracticeAttempt>[];
  bool busy = false, more = true;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (busy || !more) return;
    setState(() => busy = true);
    try {
      final next = await ref
          .read(practiceStoreProvider)
          .history(widget.id, offset: rows.length);
      if (mounted) {
        setState(() {
          rows.addAll(next);
          more = next.length == 50;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.backToQuestion,
              onPressed: () => context.go('/practice/${widget.id}'),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                context.l10n.attemptHistory,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: rows.length + 1,
          itemBuilder: (ctx, i) {
            if (i == rows.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (rows.isEmpty && !busy && !failed)
                      Text(context.l10n.noAttemptsYet),
                    if (failed) Text(context.l10n.couldNotReadTheHistory),
                    if (busy && rows.isEmpty)
                      const CircularProgressIndicator()
                    else if (more)
                      TextButton(
                        onPressed: busy ? null : () => act(context, _load),
                        child: Text(
                          busy ? context.l10n.loading : context.l10n.loadMore,
                        ),
                      ),
                  ],
                ),
              );
            }
            final a = rows[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 0,
              ),
              title: Text(
                a.status == 'draft'
                    ? context.l10n.unfinishedAttempt
                    : a.status == 'awaiting_self_grade'
                    ? context.l10n.awaitingSelfAssessment
                    : a.correct == true
                    ? context.l10n.answerCorrect
                    : context.l10n.needsCorrection,
              ),
              subtitle: Text(
                '${l10nArgument(a.startedAt.toLocal().toString().substring(0, 16))} · ${l10nArgument(a.gradingBasis == 'ai_reference'
                    ? context.l10n.aiReferenceNeedsChecking
                    : a.gradingBasis == 'self'
                    ? context.l10n.selfAssessed
                    : a.gradingBasis == 'deterministic'
                    ? context.l10n.verifiedRuleBasedGrading
                    : context.l10n.draft)}${l10nArgument(a.hintUsed ? context.l10n.hintUsedSuffix : '')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/practice/${widget.id}?attempt=${a.id}'),
            );
          },
        ),
      ),
    ],
  );
}
