import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_error.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/ui/actions.dart';
import '../review/review_screen.dart';
import 'practice_providers.dart';
import 'practice_run_screen.dart';
import 'practice_store.dart';
import 'question_card.dart';
import 'question_localization.dart';
import 'question_spec.dart';

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
  String query = '';
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
                    onPressed: () => context.go('/study'),
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
              const SizedBox(height: 10),
              Text(
                trash
                    ? context.l10n.restoredQuestionsKeepTheirAnswers
                    : context.l10n.closeTheExplanationAndTry,
              ),
              const SizedBox(height: 14),
              if (!trash)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('ai-quiz'),
                      onPressed: c.busy
                          ? null
                          : () => act(context, () async {
                              await c.prepareQuickQuiz();
                              if (context.mounted) context.go('/chat');
                            }),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(context.l10n.aiQuiz),
                    ),
                    OutlinedButton.icon(
                      key: const Key('random-practice'),
                      onPressed: () => act(context, () async {
                        final prior = await ref
                            .read(practiceStoreProvider)
                            .loadRun();
                        if (prior != null && !prior.completed) {
                          if (context.mounted) context.go('/practice/run');
                          return;
                        }
                        await ref
                            .read(practiceStoreProvider)
                            .startRandomRun(subject: c.subjectFilter);
                        if (context.mounted) context.go('/practice/run');
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
                      key: const Key('basic-practice'),
                      onPressed: () => act(context, () async {
                        final id = await ref
                            .read(practiceStoreProvider)
                            .create(
                              const QuestionSpec(
                                kind: 'numeric',
                                stem: r'解方程 $3x+5=20$，填写 $x$ 的值。',
                                answers: [
                                  ['5'],
                                ],
                                explanation: r'$3x=20-5=15$，所以 $x=5$。',
                                hint: '先将常数项移到等号另一边。',
                                topics: ['一元一次方程'],
                              ),
                              origin: 'template',
                              verification: 'template_checked',
                              operation: 'template:linear-3x5-20',
                            );
                        await ref
                            .read(practiceStoreProvider)
                            .begin(id, retry: true);
                        if (context.mounted) context.go('/practice/$id');
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
                            onPressed: () => context.go('/practice/run'),
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
                      child: Text(context.l10n.noPracticeQuestionsYetAsk),
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
                        key: Key('practice-row-${q.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        leading: Icon(
                          q.origin == 'ai'
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
                            if (v == 'edit') {
                              final detail = await store.detail(q.id);
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      QuestionEditor(initial: detail),
                                );
                              }
                            } else if (v == 'trash') {
                              await store.setDeleted(q.id, true);
                            } else if (v == 'restore') {
                              await store.setDeleted(q.id, false);
                            } else if (v == 'purge') {
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
                                    value: 'restore',
                                    child: Text(context.l10n.restoreQuestion),
                                  ),
                                  PopupMenuItem(
                                    value: 'purge',
                                    child: Text(
                                      context
                                          .l10n
                                          .permanentlyDeleteQuestionAndHistory,
                                    ),
                                  ),
                                ]
                              : [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      context.l10n.reviseQuestionAndAnswer,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'trash',
                                    child: Text(context.l10n.moveToTrash),
                                  ),
                                ],
                        ),
                        onTap: trash
                            ? null
                            : () => context.go('/practice/${q.id}'),
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
          onPressed: () => context.go('/practice'),
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
            key: ValueKey('$id:$attemptId'),
          ),
        ),
      ),
    ],
  );
}

class QuestionEditor extends ConsumerStatefulWidget {
  const QuestionEditor({this.initial, super.key});
  final QuestionDetail? initial;
  @override
  ConsumerState<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends ConsumerState<QuestionEditor> {
  final stem = TextEditingController(),
      options = TextEditingController(),
      answers = TextEditingController(),
      explanation = TextEditingController(),
      subject = TextEditingController(text: '数学'),
      hint = TextEditingController(),
      topics = TextEditingController(),
      absoluteTolerance = TextEditingController(text: '0.000001'),
      relativeTolerance = TextEditingController(text: '0'),
      timeLimit = TextEditingController();
  bool caseSensitive = true;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      // New question: default to the global subject filter, else 数学.
      final filter = ref.read(appControllerProvider).subjectFilter;
      if (filter.isNotEmpty) subject.text = filter;
      return;
    }
    final q = initial.spec;
    kind = q.kind;
    stem.text = q.stem;
    subject.text = q.subject;
    explanation.text = q.explanation;
    hint.text = q.hint;
    topics.text = q.topics.join('、');
    final ids = q.options.keys.toList();
    options.text = q.options.values.join('\n');
    final map = {
      for (var i = 0; i < ids.length; i++) ids[i]: String.fromCharCode(65 + i),
    };
    answers.text = q.answers
        .map(
          (a) => a
              .map(
                (v) => kind == 'single_choice' || kind == 'multiple_choice'
                    ? map[v] ?? v
                    : v,
              )
              .join('|'),
        )
        .join('\n');
    absoluteTolerance.text = '${q.absoluteTolerance}';
    relativeTolerance.text = '${q.relativeTolerance}';
    timeLimit.text = q.timeLimitSeconds?.toString() ?? '';
    caseSensitive = q.caseSensitive;
  }

  String kind = 'single_choice';
  bool saving = false;
  Object? failure;
  @override
  void dispose() {
    for (final c in [
      stem,
      options,
      answers,
      explanation,
      subject,
      hint,
      topics,
      absoluteTolerance,
      relativeTolerance,
      timeLimit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final lines = options.text
          .split('\n')
          .where((v) => v.trim().isNotEmpty)
          .toList();
      final choice = [
        'single_choice',
        'multiple_choice',
        'true_false',
      ].contains(kind);
      final spec = QuestionSpec(
        kind: kind,
        stem: stem.text,
        subject: subject.text.trim(),
        options: !choice
            ? {}
            : kind == 'true_false'
            ? {'true': '正确', 'false': '错误'}
            : {
                for (var i = 0; i < lines.length; i++)
                  String.fromCharCode(65 + i): lines[i].trim(),
              },
        answers: answers.text
            .split('\n')
            .where((v) => v.trim().isNotEmpty)
            .map((v) => v.split('|').map((s) => s.trim()).toList())
            .toList(),
        explanation: explanation.text,
        hint: hint.text,
        absoluteTolerance:
            double.tryParse(absoluteTolerance.text.trim()) ?? double.nan,
        relativeTolerance:
            double.tryParse(relativeTolerance.text.trim()) ?? double.nan,
        timeLimitSeconds: timeLimit.text.trim().isEmpty
            ? null
            : int.tryParse(timeLimit.text.trim()) ?? -1,
        caseSensitive: caseSensitive,
        topics: topics.text
            .split('、')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(),
      );
      final store = ref.read(practiceStoreProvider), old = widget.initial;
      final id = old == null
          ? await store.create(spec)
          : await store.revise(old.row.id, spec);
      if (mounted) {
        Navigator.pop(context);
        context.go('/practice/$id');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is FormatException
              ? e
              : const AppFormatException(
                  AppErrorCode.errorSaveCheckStorage,
                  '保存失败，请检查存储空间。',
                ),
        );
      }
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? context.l10n.addPracticeQuestion
          : context.l10n.reviseQuestionKeepOriginal,
    ),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSelectField<String>(
            initialValue: kind,
            decoration: InputDecoration(labelText: context.l10n.questionType),
            items: questionKinds.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(questionKindLabel(context, e.key)),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (v) => setState(() {
                    kind = v!;
                    // The true/false answer control only accepts 'true' /
                    // 'false'; drop a stale free-text answer from another
                    // kind so the dropdown starts empty instead of invalid.
                    if (kind == 'true_false' &&
                        answers.text.trim() != 'true' &&
                        answers.text.trim() != 'false') {
                      answers.text = '';
                    }
                  }),
          ),
          for (final (ctrl, label, lines) in [
            (subject, context.l10n.subject, 1),
            (stem, context.l10n.questionMarkdownAndMathSupported, 3),
            if (['single_choice', 'multiple_choice'].contains(kind))
              (options, context.l10n.optionsOnePerLineNumbered, 3),
            (
              answers,
              kind == 'true_false'
                  ? context.l10n.answerTrueOrFalse
                  : kind == 'fill_blank'
                  ? context.l10n.oneBlankPerLineSeparate
                  : kind == 'multiple_choice'
                  ? context.l10n.oneCorrectOptionLetterPer
                  : kind == 'short_answer'
                  ? context.l10n.referenceAnswerOptionalSelfAssess
                  : context.l10n.correctAnswerOptionLetterOr,
              2,
            ),
            (explanation, context.l10n.explanation, 3),
            (hint, context.l10n.hintOptional, 2),
            (topics, context.l10n.knowledgePointsSeparateWith, 1),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              // True/false answers are a choice, not free text: typing
              // literal "true"/"false" is error-prone and only surfaces
              // at save time.
              child: ctrl == answers && kind == 'true_false'
                  ? AppSelectField<String>(
                      initialValue:
                          ['true', 'false'].contains(answers.text.trim())
                          ? answers.text.trim()
                          : null,
                      decoration: InputDecoration(
                        labelText: context.l10n.answer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'true',
                          child: Text(context.l10n.correct),
                        ),
                        DropdownMenuItem(
                          value: 'false',
                          child: Text(context.l10n.error),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) => setState(() => answers.text = v ?? ''),
                    )
                  : TextField(
                      controller: ctrl,
                      key: ctrl == stem
                          ? const Key('question-stem')
                          : ctrl == answers
                          ? const Key('question-answers')
                          : null,
                      enabled: !saving,
                      minLines: lines,
                      maxLines: lines + 3,
                      decoration: InputDecoration(labelText: label),
                    ),
            ),
          ExpansionTile(
            title: Text(context.l10n.gradingAndTimeSettings),
            tilePadding: EdgeInsets.zero,
            children: [
              if (kind == 'numeric') ...[
                TextField(
                  controller: absoluteTolerance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.absoluteTolerance0100,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relativeTolerance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.relativeTolerance001,
                  ),
                ),
              ],
              if (kind == 'fill_blank')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.caseSensitiveAnswers),
                  value: caseSensitive,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => caseSensitive = v),
                ),
              TextField(
                controller: timeLimit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.suggestedTimeInSecondsOptional,
                ),
              ),
            ],
          ),
          if (widget.initial != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                context.l10n.saveAsANewVersion,
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (failure != null)
            Text(
              failureText(context.l10n, failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Text(
            context.l10n.checkTheQuestionAndAnswer,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(
          saving ? context.l10n.savingEllipsis : context.l10n.saveQuestion,
        ),
      ),
    ],
  );
}
