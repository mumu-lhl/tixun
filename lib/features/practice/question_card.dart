import '../review/review_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/learning_markdown.dart';
import 'practice_store.dart';
import 'practice_providers.dart';
import 'question_spec.dart';

class MessageQuestions extends ConsumerWidget {
  const MessageQuestions(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(messageQuestionsProvider(messageId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const Text('练习读取失败，请重新打开对话。'),
        data: (rows) => Column(
          children: [
            for (final q in rows)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: QuestionCard(q.id, key: ValueKey(q.id)),
              ),
          ],
        ),
      );
}

class QuestionCard extends ConsumerStatefulWidget {
  const QuestionCard(this.id, {this.attemptId, super.key});
  final String id;
  final String? attemptId;
  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  QuestionDetail? d;
  Timer? _ticker;
  String? failure;
  bool busy = true;
  List<String> answers = [];
  Future<void> _writes = Future.value();
  final controllers = <TextEditingController>[];
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool retry = false}) async {
    try {
      final store = ref.read(practiceStoreProvider);
      if (widget.attemptId == null) await store.begin(widget.id, retry: retry);
      final value = await store.detail(widget.id, attemptId: widget.attemptId);
      if (!mounted) return;
      for (final c in controllers) {
        c.dispose();
      }
      controllers.clear();
      d = value;
      _ticker?.cancel();
      if (value.spec.timeLimitSeconds != null &&
          value.latest!.status == 'draft') {
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
      answers = List.of(value.responses[value.latest!.id] ?? []);
      if (![
        'single_choice',
        'multiple_choice',
        'true_false',
      ].contains(value.spec.kind)) {
        answers = List.generate(
          value.spec.responseCount,
          (i) => i < answers.length ? answers[i] : '',
        );
        controllers.addAll(answers.map((a) => TextEditingController(text: a)));
      }
      setState(() {
        busy = false;
        failure = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failure = '题目暂时无法读取，可能已被删除。';
          busy = false;
        });
      }
    }
  }

  void _save() {
    final snapshot = List<String>.of(answers);
    final id = d!.latest!.id;
    final store = ref.read(practiceStoreProvider);
    _writes = store.draft(id, snapshot).catchError((Object e) {
      if (mounted) setState(() => failure = '草稿保存失败，请检查可用存储空间。');
    });
  }

  Future<void> _action(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    await act(context, () async {
      await _writes;
      await fn();
    });
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (d == null) {
      return failure != null ? Text(failure!) : const LinearProgressIndicator();
    }
    final detail = d!, q = detail.spec, a = detail.latest!;
    final editable = a.status == 'draft';
    final graded = a.status == 'graded';
    final store = ref.read(practiceStoreProvider),
        c = ref.read(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('quiz-${widget.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${questionKinds[q.kind]} · ${q.subject}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail.row.verification == 'unverified'
                    ? (detail.row.origin == 'ai' ? 'AI 参考答案待核对' : '参考资料 · 自主判分')
                    : detail.row.origin == 'template'
                    ? '已校验的基础练习'
                    : '用户已核对答案',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (q.timeLimitSeconds != null)
                Text(
                  editable
                      ? '剩余建议时间 ${((q.timeLimitSeconds! * 1000 - DateTime.now().difference(a.startedAt).inMilliseconds) / 1000).ceil().clamp(0, q.timeLimitSeconds!)} 秒（不强制收卷）'
                      : '建议限时 ${q.timeLimitSeconds} 秒',
                ),
            ],
          ),
          const SizedBox(height: 12),
          LearningMarkdown(q.stem),
          for (final image in detail.images)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.file(
                c.files.resolve(image.relativePath),
                height: 240,
                fit: BoxFit.contain,
                cacheWidth: 1000,
                errorBuilder: (_, _, _) => const Text('题目图片无法解码，其他内容仍可使用。'),
              ),
            ),
          if (q.topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                q.topics.join(' · '),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          for (final e in q.options.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: answers.contains(e.key)
                    ? colors.primaryContainer.withValues(alpha: .5)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: Key('option-${e.key}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: !editable || busy
                      ? null
                      : () {
                          setState(() {
                            if (q.kind == 'multiple_choice') {
                              answers.contains(e.key)
                                  ? answers.remove(e.key)
                                  : answers.add(e.key);
                            } else {
                              answers = [e.key];
                            }
                          });
                          _save();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          q.kind == 'multiple_choice'
                              ? (answers.contains(e.key)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                              : (answers.contains(e.key)
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                          color: colors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.key == 'true' || e.key == 'false'
                              ? ''
                              : '${e.key}. ',
                        ),
                        Expanded(
                          child: IgnorePointer(
                            child: LearningMarkdown(e.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: Key('quiz-answer-$i'),
                controller: controllers[i],
                enabled: !busy,
                readOnly: !editable,
                minLines: q.kind == 'short_answer' ? 3 : 1,
                maxLines: q.kind == 'short_answer' ? 8 : 2,
                decoration: InputDecoration(
                  labelText: q.kind == 'fill_blank'
                      ? '第 ${i + 1} 空'
                      : q.kind == 'numeric'
                      ? '数值答案（可填写分数）'
                      : '我的独立作答',
                ),
                onChanged: (v) {
                  answers[i] = v;
                  _save();
                },
              ),
            ),
          if (a.hintUsed && q.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: LearningMarkdown('提示：${q.hint}'),
            ),
          if (failure != null)
            Text(failure!, style: TextStyle(color: colors.error)),
          if (editable)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  key: const Key('submit-quiz'),
                  onPressed: busy
                      ? null
                      : () => _action(() async {
                          await store.submit(a.id, answers);
                        }),
                  child: Text(busy ? '正在保存…' : '提交答案'),
                ),
                if (q.hint.isNotEmpty && !a.hintUsed)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _action(() => store.useHint(a.id)),
                    child: const Text('给我提示'),
                  ),
              ],
            ),
          if (!editable) ...[
            const Divider(height: 28),
            Text(
              graded
                  ? (a.correct == true ? '本次作答正确' : '本次作答需要订正')
                  : '先对照参考，再给自己的作答判分',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (a.gradingBasis == 'ai_reference')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '本次结果按作答时的 AI 参考答案记录，不作为已验证的掌握证据。核对题目后，新的作答会使用更新后的依据。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            if (q.answers.isNotEmpty)
              LearningMarkdown(
                '参考答案：${q.answers.map((a) => a.join(' / ')).join('；')}',
              ),
            if (q.explanation.isNotEmpty) LearningMarkdown(q.explanation),
            if (graded)
              Text(
                '${a.hintUsed ? '使用了提示' : '未使用提示'} · ${a.gradingBasis == 'self' ? '自主判分' : '规则判分'} · 用时 ${((a.elapsedMilliseconds ?? 0) / 1000).round()} 秒',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (a.status == 'awaiting_self_grade')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
                            await store.selfGrade(a.id, true);
                          }),
                    child: const Text('独立做对了'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
                            await store.selfGrade(a.id, false);
                          }),
                    child: const Text('还需要练习'),
                  ),
                ],
              ),
            if (graded)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.attemptId == null)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              await _load(retry: true);
                            },
                      child: const Text('再做一次'),
                    ),
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () => act(context, () async {
                            await c.prepareVariant(detail);
                            if (context.mounted) context.go('/chat');
                          }),
                    child: const Text('讲解与变式训练'),
                  ),
                  if (detail.row.origin == 'ai' &&
                      detail.row.verification == 'unverified')
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => act(context, () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('确认已独立核对'),
                                  content: const Text(
                                    '请核对题目条件、答案和推导。确认只影响今后的作答统计，不会追溯修改已有记录。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('已核对'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await store.verify(widget.id);
                                await _load();
                              }
                            }),
                      child: const Text('核对参考答案'),
                    ),
                ],
              ),
          ],
          QuestionReviewStatus(widget.id),
          TextButton(
            onPressed: () => context.go('/practice/${widget.id}/history'),
            child: const Text('查看全部作答历史'),
          ),
          if (detail.row.parentQuestionId != null)
            TextButton(
              onPressed: () =>
                  context.go('/practice/${detail.row.parentQuestionId}'),
              child: Text(detail.row.origin == 'ai' ? '查看变式来源题目' : '查看修订前题目'),
            ),
          if (detail.attempts.length > 1)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('最近作答（最多显示 50 次）'),
              children: [
                for (final old in detail.attempts.where(
                  (a) => a.status == 'graded',
                ))
                  ListTile(
                    dense: true,
                    title: Text(
                      '${old.submittedAt?.toLocal().toString().substring(0, 16)} · ${old.correct == true ? '正确' : '需订正'}${old.hintUsed ? ' · 有提示' : ''}',
                    ),
                    subtitle: Text(
                      '我的答案：${(detail.responses[old.id] ?? []).join('；')}\n依据：${old.gradingBasis == 'ai_reference'
                          ? 'AI 待核对参考'
                          : old.gradingBasis == 'self'
                          ? '自主判分'
                          : '已核对答案的确定性判分'}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
