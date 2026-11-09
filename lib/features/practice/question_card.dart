import '../scratchpad/scratchpad_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/image_viewer.dart';
import '../../core/ui/learning_markdown.dart';
import '../review/review_screen.dart';
import 'practice_providers.dart';
import 'practice_store.dart';
import 'question_spec.dart';
import '../chat/message_reasoning.dart';

class MessageQuestions extends ConsumerWidget {
  const MessageQuestions(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(messageQuestionsProvider(messageId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => Text(context.tr("练习读取失败，请重新打开对话。")),
        data: (rows) => Column(
          children: [
            for (final q in rows)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: QuestionCard(
                  q.id,
                  showReasoning: false,
                  key: ValueKey(q.id),
                ),
              ),
          ],
        ),
      );
}

class QuestionCard extends ConsumerStatefulWidget {
  const QuestionCard(
    this.id, {
    this.attemptId,
    this.showReasoning = true,
    super.key,
  });
  final bool showReasoning;
  final String id;
  final String? attemptId;
  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  QuestionDetail? d;
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

  Future<void> _showZoomedImage(
    BuildContext context,
    List<PracticeImage> images,
    int index,
  ) {
    final files = ref.read(appControllerProvider).files;
    return showImageViewer(
      context,
      images: [
        for (final image in images)
          ImageViewerItem(
            file: files.resolve(image.relativePath),
            heroTag: 'question-image-${image.id}',
            cacheWidth: 1600,
            errorText: context.tr("题目图片无法解码，其他内容仍可使用。"),
          ),
      ],
      initialIndex: index,
      title: context.tr("题目图片"),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (d == null) {
      if (failure == null) return const LinearProgressIndicator();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(failure!)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => _load(), child: Text(context.tr("重试"))),
        ],
      );
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
                '${context.tr(questionKinds[q.kind]!)} · ${context.subjectName(q.subject)}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail.row.verification == 'unverified'
                    ? (detail.row.origin == 'ai'
                          ? context.tr("AI 参考答案待核对")
                          : context.tr("参考资料 · 自主判分"))
                    : detail.row.origin == 'template'
                    ? context.tr("已校验的基础练习")
                    : context.tr("用户已核对答案"),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (q.timeLimitSeconds != null)
                editable
                    ? _RemainingTime(
                        limitSeconds: q.timeLimitSeconds!,
                        startedAt: a.startedAt,
                      )
                    : Text(context.tr("建议限时 {0} 秒", [q.timeLimitSeconds])),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ScratchpadButton('practice:${widget.id}'),
          ),
          LearningMarkdown(q.stem),
          if (widget.showReasoning && detail.row.sourceMessageId != null)
            SourceReasoning(detail.row.sourceMessageId!),
          for (final image in detail.images)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () => _showZoomedImage(
                  context,
                  detail.images,
                  detail.images.indexWhere((i) => i.id == image.id),
                ),
                child: Hero(
                  tag: 'question-image-${image.id}',
                  child: Image.file(
                    c.files.resolve(image.relativePath),
                    height: 240,
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                    errorBuilder: (_, _, _) =>
                        Text(context.tr("题目图片无法解码，其他内容仍可使用。")),
                  ),
                ),
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
                // After grading, mark the outcome on the options themselves:
                // correct options get a primary tint with a check, a wrong
                // pick gets an error tint with a cross. Before grading the
                // row only shows the user's selection, as before.
                color: graded
                    ? (q.answers.expand((a) => a).contains(e.key)
                          ? colors.primaryContainer
                          : answers.contains(e.key)
                          ? colors.errorContainer
                          : colors.surfaceContainerLow)
                    : answers.contains(e.key)
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
                          graded
                              ? (q.answers.expand((a) => a).contains(e.key)
                                    ? Icons.check_circle
                                    : answers.contains(e.key)
                                    ? Icons.cancel
                                    : q.kind == 'multiple_choice'
                                    ? Icons.check_box_outline_blank
                                    : Icons.radio_button_off)
                              : q.kind == 'multiple_choice'
                              ? (answers.contains(e.key)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                              : (answers.contains(e.key)
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                          color: graded
                              ? (q.answers.expand((a) => a).contains(e.key)
                                    ? colors.primary
                                    : answers.contains(e.key)
                                    ? colors.error
                                    : colors.onSurfaceVariant)
                              : colors.primary,
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
                keyboardType: q.kind == 'numeric'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                minLines: q.kind == 'short_answer' ? 3 : 1,
                maxLines: q.kind == 'short_answer' ? 8 : 2,
                decoration: InputDecoration(
                  labelText: q.kind == 'fill_blank'
                      ? context.tr("第 {0} 空", [i + 1])
                      : q.kind == 'numeric'
                      ? context.tr("数值答案（可填写分数）")
                      : context.tr("我的独立作答"),
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
            Text(context.tr(failure!), style: TextStyle(color: colors.error)),
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
                  child: Text(busy ? context.tr("正在保存…") : context.tr("提交答案")),
                ),
                if (q.hint.isNotEmpty && !a.hintUsed)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _action(() => store.useHint(a.id)),
                    child: Text(context.tr("给我提示")),
                  ),
              ],
            ),
          if (!editable) ...[
            const Divider(height: 28),
            Text(
              graded
                  ? (a.correct == true
                        ? context.tr("本次作答正确")
                        : context.tr("本次作答需要订正"))
                  : context.tr("先对照参考，再给自己的作答判分"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (a.gradingBasis == 'ai_reference')
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  context.tr(
                    "本次结果按作答时的 AI 参考答案记录，不作为已验证的掌握证据。核对题目后，新的作答会使用更新后的依据。",
                  ),
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
                context.tr("{0} · {1} · 用时 {2} 秒", [
                  a.hintUsed ? context.tr("使用了提示") : context.tr("未使用提示"),
                  a.gradingBasis == 'self'
                      ? context.tr("自主判分")
                      : context.tr("规则判分"),
                  ((a.elapsedMilliseconds ?? 0) / 1000).round(),
                ]),
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
                    child: Text(context.tr("独立做对了")),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
                            await store.selfGrade(a.id, false);
                          }),
                    child: Text(context.tr("还需要练习")),
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
                      child: Text(context.tr("再做一次")),
                    ),
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () => act(context, () async {
                            await c.prepareVariant(detail);
                            if (context.mounted) context.go('/chat');
                          }),
                    child: Text(context.tr("讲解与变式训练")),
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
                                  title: Text(context.tr("确认已独立核对")),
                                  content: Text(
                                    context.tr(
                                      "请核对题目条件、答案和推导。确认只影响今后的作答统计，不会追溯修改已有记录。",
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
                                      child: Text(context.tr("已核对")),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await store.verify(widget.id);
                                await _load();
                              }
                            }),
                      child: Text(context.tr("核对参考答案")),
                    ),
                ],
              ),
          ],
          QuestionReviewStatus(widget.id),
          TextButton(
            onPressed: () => context.go('/practice/${widget.id}/history'),
            child: Text(context.tr("查看全部作答历史")),
          ),
          if (detail.row.parentQuestionId != null)
            TextButton(
              onPressed: () =>
                  context.go('/practice/${detail.row.parentQuestionId}'),
              child: Text(
                detail.row.origin == 'ai'
                    ? context.tr("查看变式来源题目")
                    : context.tr("查看修订前题目"),
              ),
            ),
          if (detail.attempts.length > 1)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.tr("最近作答（最多显示 50 次）")),
              children: [
                for (final old in detail.attempts.where(
                  (a) => a.status == 'graded',
                ))
                  ListTile(
                    dense: true,
                    title: Text(
                      context.tr("{0} · {1}{2}", [
                        old.submittedAt?.toLocal().toString().substring(0, 16),
                        old.correct == true
                            ? context.tr("正确")
                            : context.tr("需订正"),
                        old.hintUsed ? context.tr(" · 有提示") : '',
                      ]),
                    ),
                    subtitle: Text(
                      context.tr("我的答案：{0}\n依据：{1}", [
                        (detail.responses[old.id] ?? []).join('；'),
                        old.gradingBasis == 'ai_reference'
                            ? context.tr("AI 待核对参考")
                            : old.gradingBasis == 'self'
                            ? context.tr("自主判分")
                            : context.tr("已核对答案的确定性判分"),
                      ]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Countdown label for a timed question. It owns its own one-second timer
/// so only this text rebuilds, instead of the whole question card (with all
/// its Markdown and math parsing) ticking every second.
class _RemainingTime extends StatefulWidget {
  const _RemainingTime({required this.limitSeconds, required this.startedAt});
  final int limitSeconds;
  final DateTime startedAt;
  @override
  State<_RemainingTime> createState() => _RemainingTimeState();
}

class _RemainingTimeState extends State<_RemainingTime> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        ((widget.limitSeconds * 1000 -
                    DateTime.now()
                        .difference(widget.startedAt)
                        .inMilliseconds) /
                1000)
            .ceil()
            .clamp(0, widget.limitSeconds);
    return Text(context.tr("剩余建议时间 {0} 秒（不强制收卷）", [remaining]));
  }
}
