import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';
import 'question_card.dart';
import 'question_spec.dart';

final practiceListProvider = FutureProvider.autoDispose
    .family<List<PracticeQuestion>, String>(
      (ref, query) => ref.watch(practiceStoreProvider).list(query: query),
    );

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});
  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(practiceListProvider(query));
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
                    tooltip: '返回学习',
                    onPressed: () => context.go('/study'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '主动训练',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('合上解析，独立尝试。作答记录在此设备保存，已有题目支持离线练习。'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('ai-quiz'),
                    onPressed: c.busy
                        ? null
                        : () => act(context, () async {
                            await c.newSession();
                            await c.mode('exam');
                            await c.renameSession(c.selected!, '数学 · 检测训练');
                            await c.draft('请给我出一道适合高中生的数学检测题，让我直接作答。不要提前透露答案。');
                            if (context.mounted) context.go('/chat');
                          }),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI 出题'),
                  ),
                  OutlinedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const QuestionEditor(),
                    ),
                    child: const Text('手动录题'),
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
                          );
                      if (context.mounted) context.go('/practice/$id');
                    }),
                    child: const Text('离线基础练习'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索题干',
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
                onPressed: () => ref.invalidate(practiceListProvider(query)),
                child: const Text('读取失败，点击重试'),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('还没有练习题。可以请 AI 出题、手动录入，或从错题与知识详情开始训练。'),
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
                          '${q.subject} · ${questionKinds[q.kind]} · ${q.verification == 'unverified' ? '参考答案待核对' : '已核对答案'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/practice/${q.id}'),
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
  const PracticeDetailScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/practice'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('全部训练'),
        ),
      ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: QuestionCard(id, key: ValueKey(id)),
        ),
      ),
    ],
  );
}

class QuestionEditor extends ConsumerStatefulWidget {
  const QuestionEditor({super.key});
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
      topics = TextEditingController();
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
        topics: topics.text
            .split('、')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(),
      );
      final id = await ref.read(practiceStoreProvider).create(spec);
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
    title: const Text('录入练习题'),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: '题型'),
            items: questionKinds.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: saving ? null : (v) => setState(() => kind = v!),
          ),
          for (final (ctrl, label, lines) in [
            (subject, '科目', 1),
            (stem, '题干（支持 Markdown 和公式）', 3),
            if (['single_choice', 'multiple_choice'].contains(kind))
              (options, '选项：每行一项，自动编号 A、B…', 3),
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
                enabled: !saving,
                minLines: lines,
                maxLines: lines + 3,
                decoration: InputDecoration(labelText: label),
              ),
            ),
          if (failure != null)
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          const Text(
            '请自行核对答案与题目。手动录入的答案会标记为用户已核对。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? '保存中…' : '保存题目'),
      ),
    ],
  );
}
