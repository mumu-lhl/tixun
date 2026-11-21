import "../../core/ui/app_menu.dart";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/l10n/app_error.dart";
import "../../core/l10n/app_error_localization.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/markdown_editor.dart";
import "../review/review_screen.dart";
import "practice_providers.dart";
import "practice_run_screen.dart";
import "practice_store.dart";
import "question_card.dart";
import "question_localization.dart";
import "question_spec.dart";

part "question_editor.dart";

final practiceListProvider = FutureProvider.autoDispose
    .family<
      List<PracticeQuestion>,
      ({String query, bool trash, String subject, int limit})
    >(
      (ref, filter) => ref
          .watch(practiceStoreProvider)
          .list(
            query: filter.query,
            subject: filter.subject,
            trash: filter.trash,
            limit: filter.limit,
          ),
    );

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});
  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  String query = "";
  bool trash = false;
  int limit = 200;
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final filter = (
      query: query,
      trash: trash,
      subject: c.subjectFilter,
      limit: limit,
    );
    final rows = ref.watch(practiceListProvider(filter));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.backToStudy,
                    onPressed: () => context.go("/study"),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trash
                          ? context.l10n.practiceTrash
                          : context.l10n.practice,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: trash
                        ? context.l10n.backToQuestionBank
                        : context.l10n.practiceTrash,
                    onPressed: () => setState(() {
                      trash = !trash;
                      limit = 200;
                    }),
                    icon: Icon(
                      trash
                          ? Icons.edit_note
                          : Icons.restore_from_trash_outlined,
                    ),
                  ),
                ],
              ),
              if (trash) ...[
                const SizedBox(height: 10),
                Text(context.l10n.restoredQuestionsKeepTheirAnswers),
              ],
              const SizedBox(height: 14),
              if (!trash)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key("ai-quiz"),
                      onPressed: c.busy
                          ? null
                          : () => act(context, () async {
                              await c.prepareQuickQuiz();
                              if (context.mounted) context.go("/chat");
                            }),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(context.l10n.aiQuiz),
                    ),
                    OutlinedButton.icon(
                      key: const Key("random-practice"),
                      onPressed: () => act(context, () async {
                        final prior = await ref
                            .read(practiceStoreProvider)
                            .loadRun();
                        if (prior != null && !prior.completed) {
                          if (context.mounted) context.go("/practice/run");
                          return;
                        }
                        await ref
                            .read(practiceStoreProvider)
                            .startRandomRun(subject: c.subjectFilter);
                        if (context.mounted) context.go("/practice/run");
                      }),
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: Text(context.l10n.randomQuizFromExistingQuestions),
                    ),
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const QuestionEditor(),
                      ),
                      child: Text(context.l10n.addQuestionManually),
                    ),
                    TextButton(
                      key: const Key("basic-practice"),
                      onPressed: () => act(context, () async {
                        final id = await ref
                            .read(practiceStoreProvider)
                            .create(
                              const QuestionSpec(
                                kind: "numeric",
                                stem: r"解方程 $3x+5=20$，填写 $x$ 的值。",
                                answers: [
                                  ["5"],
                                ],
                                explanation: r"$3x=20-5=15$，所以 $x=5$。",
                                hint: "先将常数项移到等号另一边。",
                                topics: ["一元一次方程"],
                              ),
                              origin: "template",
                              verification: "template_checked",
                              operation: "template:linear-3x5-20",
                            );
                        await ref
                            .read(practiceStoreProvider)
                            .begin(id, retry: true);
                        if (context.mounted) context.go("/practice/$id");
                      }),
                      child: Text(context.l10n.offlineBasicPractice),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              ref
                  .watch(practiceRunProvider)
                  .maybeWhen(
                    data: (run) => run == null
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: () => context.go("/practice/run"),
                            child: Text(
                              run.completed
                                  ? context.l10n.viewThePreviousQuiz
                                  : context.l10n.resumeQuizQuestion(
                                      l10nArgument((run.index + 1)),
                                      l10nArgument((run.ids.length)),
                                    ),
                            ),
                          ),
                    error: (_, _) => TextButton(
                      onPressed: () => act(context, () async {
                        await ref.read(practiceStoreProvider).clearRun();
                      }),
                      child: Text(context.l10n.endUnavailableQuizKeepRecords),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: context.l10n.searchQuestions,
                ),
                onChanged: (v) => setState(() {
                  query = v.trim();
                  limit = 200;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(practiceListProvider(filter)),
                child: Text(context.l10n.couldNotReadDataTap),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        query.isNotEmpty
                            ? context.l10n.noMatchingQuestions
                            : trash
                            ? context.l10n.trashIsEmpty
                            : context.l10n.noPracticeQuestionsYet,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: rows.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == rows.length) {
                        // A full page may hide older questions: offer the
                        // next page instead of silently stopping at 200.
                        if (rows.length < limit) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: TextButton(
                              onPressed: () => setState(() => limit += 200),
                              child: Text(context.l10n.loadMore),
                            ),
                          ),
                        );
                      }
                      final q = rows[i];
                      return ListTile(
                        key: Key("practice-row-${q.id}"),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        leading: Icon(
                          q.origin == "ai"
                              ? Icons.auto_awesome_outlined
                              : Icons.edit_note,
                        ),
                        title: Text(
                          plainTextPreview(q.stem),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${l10nArgument(context.subjectName(q.subject))} · ${l10nArgument(questionKindLabel(context, q.kind))} · ${l10nArgument(q.verification == 'unverified' ? context.l10n.referenceNeedsChecking : context.l10n.verifiedAnswer)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          popUpAnimationStyle: menuAnimation(context),
                          tooltip: context.l10n.questionActions,
                          onSelected: (v) => act(context, () async {
                            final store = ref.read(practiceStoreProvider);
                            if (v == "edit") {
                              final detail = await store.detail(q.id);
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      QuestionEditor(initial: detail),
                                );
                              }
                            } else if (v == "trash") {
                              await store.setDeleted(q.id, true);
                            } else if (v == "restore") {
                              await store.setDeleted(q.id, false);
                            } else if (v == "purge") {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    context
                                        .l10n
                                        .permanentlyDeletePracticeQuestion,
                                  ),
                                  scrollable: true,
                                  content: Text(
                                    context.l10n.permanentlyDeleteAndAllIts(
                                      l10nArgument((q.stem)),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        context.l10n.deletePermanently,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) await store.purge(q.id);
                            }
                          }),
                          itemBuilder: (_) => trash
                              ? [
                                  PopupMenuItem(
                                    value: "restore",
                                    child: Text(context.l10n.restoreQuestion),
                                  ),
                                  PopupMenuItem(
                                    value: "purge",
                                    child: Text(
                                      context
                                          .l10n
                                          .permanentlyDeleteQuestionAndHistory,
                                    ),
                                  ),
                                ]
                              : [
                                  PopupMenuItem(
                                    value: "edit",
                                    child: Text(
                                      context.l10n.reviseQuestionAndAnswer,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: "trash",
                                    child: Text(context.l10n.moveToTrash),
                                  ),
                                ],
                        ),
                        onTap: trash
                            ? null
                            : () => context.go("/practice/${q.id}"),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class PracticeDetailScreen extends StatelessWidget {
  const PracticeDetailScreen(this.id, {this.attemptId, super.key});
  final String id;
  final String? attemptId;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go("/practice"),
          icon: const Icon(Icons.arrow_back),
          label: Text(context.l10n.allPractice),
        ),
      ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: QuestionCard(
            id,
            attemptId: attemptId,
            key: ValueKey("$id:$attemptId"),
          ),
        ),
      ),
    ],
  );
}
