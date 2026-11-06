import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';
import 'practice_run_screen.dart';
import 'practice_store.dart';
import 'question_card.dart';
import 'question_spec.dart';

final practiceListProvider = FutureProvider.autoDispose
    .family<List<PracticeQuestion>, ({String query, bool trash})>(
      (ref, filter) => ref
          .watch(practiceStoreProvider)
          .list(query: filter.query, trash: filter.trash),
    );

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});
  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  String query = '';
  bool trash = false;
  @override
  Widget build(BuildContext context) {
    final filter = (query: query, trash: trash);
    final rows = ref.watch(practiceListProvider(filter));
    final c = ref.watch(appControllerProvider);
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
                    tooltip: context.tr("返回学习"),
                    onPressed: () => context.go('/study'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trash ? context.tr("练习回收区") : context.tr("主动训练"),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: trash ? context.tr("返回题库") : context.tr("练习回收区"),
                    onPressed: () => setState(() => trash = !trash),
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
                    ? context.tr("恢复后可继续查看题目和作答；永久删除会一并删除该题的训练与复习记录。")
                    : context.tr("合上解析，独立尝试。作答记录在此设备保存，已有题目支持离线练习。"),
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
                      label: Text(context.tr("AI 出题")),
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
                        await ref.read(practiceStoreProvider).startRandomRun();
                        if (context.mounted) context.go('/practice/run');
                      }),
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: Text(context.tr("已有题随机小测")),
                    ),
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const QuestionEditor(),
                      ),
                      child: Text(context.tr("手动录题")),
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
                      child: Text(context.tr("离线基础练习")),
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
                                  ? context.tr("查看上一轮小测")
                                  : context.tr("继续小测（第 {0}/{1} 题）", [
                                      run.index + 1,
                                      run.ids.length,
                                    ]),
                            ),
                          ),
                    error: (_, _) => TextButton(
                      onPressed: () => act(context, () async {
                        await ref.read(practiceStoreProvider).clearRun();
                      }),
                      child: Text(context.tr("结束无法恢复的小测，保留记录")),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: context.tr("搜索题干"),
                ),
                onChanged: (v) => setState(() => query = v.trim()),
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
                child: Text(context.tr("读取失败，点击重试")),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        context.tr("还没有练习题。可以请 AI 出题、手动录入，或从错题与知识详情开始训练。"),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
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
                          q.stem,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          context.tr("{0} · {1} · {2}", [
                            context.subjectName(q.subject),
                            context.tr(questionKinds[q.kind]!),
                            q.verification == 'unverified'
                                ? context.tr("参考答案待核对")
                                : context.tr("已核对答案"),
                          ]),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: context.tr("题目操作"),
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
                                  title: Text(context.tr("永久删除练习？")),
                                  content: Text(
                                    context.tr(
                                      "将永久删除“{0}”及其所有作答和复习记录。该操作无法撤销，独立的知识、错题和其他题目仍保留。",
                                      [q.stem],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.tr("取消")),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.tr("永久删除")),
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
                                    child: Text(context.tr("恢复题目")),
                                  ),
                                  PopupMenuItem(
                                    value: 'purge',
                                    child: Text(context.tr("永久删除题目与记录")),
                                  ),
                                ]
                              : [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.tr("修订题目与答案")),
                                  ),
                                  PopupMenuItem(
                                    value: 'trash',
                                    child: Text(context.tr("移入回收区")),
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
          label: Text(context.tr("全部训练")),
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
    if (initial == null) return;
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
  String? failure;
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
      final links = old == null
          ? <PracticeQuestionKnowledgeData>[]
          : await (store.db.select(
              store.db.practiceQuestionKnowledge,
            )..where((l) => l.questionId.equals(old.row.id))).get();
      final id = await store.create(
        spec,
        parentId: old?.row.id,
        mistakeId: old?.row.mistakeId,
        knowledgeIds: links.map((l) => l.knowledgeId).toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        context.go('/practice/$id');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is FormatException ? e.message : '保存失败，请检查存储空间。',
        );
      }
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? context.tr("录入练习题") : context.tr("修订练习（保留旧版）"),
    ),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: kind,
            decoration: InputDecoration(labelText: context.tr("题型")),
            items: questionKinds.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(context.tr(e.value)),
                  ),
                )
                .toList(),
            onChanged: saving ? null : (v) => setState(() => kind = v!),
          ),
          for (final (ctrl, label, lines) in [
            (subject, '科目', 1),
            (stem, '题干（支持 Markdown 和公式）', 3),
            if (['single_choice', 'multiple_choice'].contains(kind))
              (options, '选项（每行一项，自动编号 A、B…）', 3),
            (
              answers,
              kind == 'true_false'
                  ? '答案：true 或 false'
                  : kind == 'fill_blank'
                  ? '每行一个空，同义答案用 | 分隔'
                  : kind == 'multiple_choice'
                  ? '每行一个正确选项字母'
                  : kind == 'short_answer'
                  ? '参考答案（可选，作答后自主判分）'
                  : '正确答案（选项字母或数值）',
              2,
            ),
            (explanation, '解析', 3),
            (hint, '提示（可选）', 2),
            (topics, '知识点（用顿号分隔）', 1),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: ctrl,
                key: ctrl == stem
                    ? const Key('question-stem')
                    : ctrl == answers
                    ? const Key('question-answers')
                    : null,
                enabled: !saving,
                minLines: lines,
                maxLines: lines + 3,
                decoration: InputDecoration(labelText: context.tr(label)),
              ),
            ),
          ExpansionTile(
            title: Text(context.tr("判分与时间设置")),
            tilePadding: EdgeInsets.zero,
            children: [
              if (kind == 'numeric') ...[
                TextField(
                  controller: absoluteTolerance,
                  decoration: InputDecoration(
                    labelText: context.tr("数值绝对容差（0–100）"),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relativeTolerance,
                  decoration: InputDecoration(
                    labelText: context.tr("相对容差（0–0.1）"),
                  ),
                ),
              ],
              if (kind == 'fill_blank')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr("答案区分大小写")),
                  value: caseSensitive,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => caseSensitive = v),
                ),
              TextField(
                controller: timeLimit,
                decoration: InputDecoration(
                  labelText: context.tr("建议答题秒数（可选，10–7200）"),
                ),
              ),
            ],
          ),
          if (widget.initial != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                context.tr("保存为新版本，原题目与作答记录保留。新的作答使用修订后的答案。"),
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (failure != null)
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Text(
            context.tr("请自行核对答案与题目。手动录入的答案会标记为用户已核对。"),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.tr("取消")),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? context.tr("保存中…") : context.tr("保存题目")),
      ),
    ],
  );
}
